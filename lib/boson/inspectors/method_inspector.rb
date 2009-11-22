module Boson
  # Gathers method attributes by redefining method_added and capturing method
  # calls before a method. This module also saves method locations so CommentInspector
  # can scrape their commented method attributes.
  module MethodInspector
    extend self
    attr_accessor :current_module
    attr_reader :mod_store
    @mod_store ||= {}
    METHODS = [:config, :desc, :options, :render_options]

    # The method_added used while scraping method attributes.
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
        (@mod_store[mod] ||= {})[e] ||= {}
        (store(mod)[:temp] ||= {})[e] = val
      end
    end

    # Scrapes a method's arguments using ArgumentInspector.
    def scrape_arguments(meth)
      store[:method_args] ||= {}

      o = Object.new
      o.extend(@current_module)
      # private methods return nil
      if (val = ArgumentInspector.scrape_with_eval(meth, @current_module, o))
        store[:method_args][meth.to_s] = val
      end
    end

    CALLER_REGEXP = RUBY_VERSION < '1.9' ? /in `load_source'/ : /in `<module:.*>'/
    # Returns an array of the file and line number at which a method starts using
    # a caller array. Necessary information for CommentInspector to function.
    def find_method_locations(stack)
      if (line = stack.find {|e| e =~ CALLER_REGEXP })
        (line =~ /^(.*):(\d+)/) ? [$1, $2.to_i] : nil
      end
    end

    #:stopdoc:
    def find_method_locations_for_19(klass, meth)
      if (klass = Util.any_const_get(klass)) && (meth_location = klass.method(meth).source_location) &&
        meth_location[0]
        meth_location
      end
    end

    # Hash of a module's method attributes i.e. descriptions, options by method and then attribute
    def store(mod=@current_module)
      @mod_store[mod]
    end

    def current_module=(mod)
      @current_module = mod
      @mod_store[mod] ||= {}
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
    #:startdoc:
  end
end