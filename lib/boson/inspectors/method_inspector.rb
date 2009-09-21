module Boson
  module MethodInspector
    extend self
    attr_accessor :current_module
    attr_reader :mod_store
    @mod_store ||= {}

    # Hash of a module's method attributes i.e. descriptions, options by method and then attribute
    def store(mod=@current_module)
      @mod_store[mod]
    end

    def current_module=(mod)
      @current_module = mod
      @mod_store[mod] ||= {}
    end
  
    def new_method_added(mod, meth)
      return unless mod.name[/^Boson::Commands::/]
      self.current_module = mod
      store[:descriptions][meth.to_s] = store[:desc] if store[:desc]
      store[:options][meth.to_s] = store[:opts] if store[:opts]

      if store[:opts].nil? || store[:desc].nil?
        store[:method_locations] ||= {}
        if (result = find_method_locations(caller))
          store[:method_locations][meth.to_s] = result
        end
      end
      store[:desc] = nil if store[:desc]
      store[:opts] = nil if store[:opts]
      scrape_arguments(meth) if (store[:options] && store[:options].key?(meth.to_s)) || options_in_file?(meth.to_s)
    end

    def options(mod, opts)
      store(mod)[:options] ||= {}
      store(mod)[:opts] = opts
    end

    def desc(mod, description)
      store(mod)[:descriptions] ||= {}
      store(mod)[:desc] = description
    end

    def scrape_arguments(meth)
      store[:method_args] ||= {}

      o = Object.new
      o.extend(@current_module)
      # private methods return nil
      if (val = ArgumentInspector.determine_method_args(meth, @current_module, o))
        store[:method_args][meth.to_s] = val
      end
    end

    def options_in_file?(meth)
      return false if !(method_location = store[:method_locations] && store[:method_locations][meth])
      File.exists?(method_location[0]) && CommentInspector.options_from_file(FileLibrary.read_library_file(method_location[0]), method_location[1])
    end

    # returns file and line no of method given caller array
    def find_method_locations(stack)
      if (line = stack.find {|e| e =~ /in `load_source'/ })
        (line =~ /^(.*):(\d+)/) ? [$1, $2.to_i] : nil
      end
    end
  end
end