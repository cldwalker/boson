module Boson
  # Gathers method attributes by redefining method_added and capturing method
  # calls before a method.
  module MethodInspector
    extend self
    attr_accessor :current_module, :mod_store
    @mod_store ||= {}
    METHODS = [:config, :desc, :options]
    SCRAPEABLE_METHODS = [:options]
    METHOD_CLASSES = {:config=>Hash, :desc=>String, :options=>Hash}
    ALL_METHODS = METHODS + [:option]

    def safe_new_method_added(mod, meth)
      return unless mod.to_s[/^Boson::Commands::/]
      new_method_added(mod, meth)
    end

    # The method_added used while scraping method attributes.
    def new_method_added(mod, meth)
      self.current_module = mod
      store[:temp] ||= {}
      METHODS.each do |e|
        store[e][meth.to_s] = store[:temp][e] if store[:temp][e]
      end
      (store[:options][meth.to_s] ||= {}).merge! store[:temp][:option] if store[:temp][:option]

      if store[:temp].size < ALL_METHODS.size
        store[:method_locations] ||= {}
        if (result = find_method_locations(mod, meth))
          store[:method_locations][meth.to_s] = result
        end
      end
      store[:temp] = {}
      if SCRAPEABLE_METHODS.any? {|m| has_inspector_method?(meth, m) }
        set_arguments(mod, meth)
      end
    end

    METHODS.each do |e|
      define_method(e) do |mod, val|
        (@mod_store[mod] ||= {})[e] ||= {}
        (store(mod)[:temp] ||= {})[e] = val
      end
    end

    def option(mod, name, value)
      (@mod_store[mod] ||= {})[:options] ||= {}
      (store(mod)[:temp] ||= {})[:option] ||= {}
      (store(mod)[:temp] ||= {})[:option][name] = value
    end

    def set_arguments(mod, meth)
      store[:args] ||= {}
      file = find_method_locations(mod, meth)[0]

      if File.exists?(file)
        body = File.read(file)
        store[:args][meth.to_s] = scrape_arguments body, meth
      end
    end

    # Returns argument arrays
    def scrape_arguments(file_string, meth)
      tabspace = "[ \t]"
      if match = /^#{tabspace}*def#{tabspace}+(?:\w+\.)?#{Regexp.quote(meth)}#{tabspace}*($|(?:\(|\s+)([^\n\)]+)\s*\)?\s*$)/.match(file_string)
        (match.to_a[2] || '').strip.split(/\s*,\s*/).map {|e| e.split(/\s*=\s*/)}
      end
    end

    # Returns an array of the file and line number at which a method starts
    # using a method
    def find_method_locations(mod, meth)
      mod.instance_method(meth).source_location
    end

    #:stopdoc:
    def find_class_method_locations(klass, meth)
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
      true
    end
    #:startdoc:
  end
end
