module Boson
  module MethodInspector
    extend self
    attr_accessor :current_module
    attr_reader :mod_store
    @mod_store ||= {}
    METHODS = [:desc, :options, :render_options]

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
      store[:temp] ||= {}
      METHODS.each do |e|
        store[e][meth.to_s] = store[:temp][e] if store[:temp][e]
      end

      if store[:temp].size < METHODS.size
        store[:method_locations] ||= {}
        if (result = find_method_locations(caller))
          store[:method_locations][meth.to_s] = result
        end
      end
      store[:temp] = {}
      scrape_arguments(meth) if has_inspector_method?(meth, :options) || has_inspector_method?(meth,:render_options)
    end

    METHODS.each do |e|
      define_method(e) do |mod, val|
        store(mod)[e] ||= {}
        (store(mod)[:temp] ||= {})[e] = val
      end
    end

    def scrape_arguments(meth)
      store[:method_args] ||= {}

      o = Object.new
      o.extend(@current_module)
      # private methods return nil
      if (val = ArgumentInspector.scrape_with_eval(meth, @current_module, o))
        store[:method_args][meth.to_s] = val
      end
    end

    def has_inspector_method?(meth, inspector)
      (store[inspector] && store[inspector].key?(meth.to_s)) || inspector_in_file?(meth.to_s, inspector)
    end

    def inspector_in_file?(meth, inspector_method)
      return false if !(file_line = store[:method_locations] && store[:method_locations][meth])
      if File.exists?(file_line[0]) && (options = CommentInspector.scrape(
        FileLibrary.read_library_file(file_line[0]), file_line[1], @current_module, inspector_method) )
        (store[inspector_method] ||= {})[meth] = options
      end
    end

    # returns file and line no of method given caller array
    def find_method_locations(stack)
      if (line = stack.find {|e| e =~ /in `load_source'/ })
        (line =~ /^(.*):(\d+)/) ? [$1, $2.to_i] : nil
      end
    end
  end
end