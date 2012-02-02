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
      if store[:temp][:option]
        (store[:options][meth.to_s] ||= {}).merge! store[:temp][:option]
      end
      during_new_method_added mod, meth
      store[:temp] = {}

      if SCRAPEABLE_METHODS.any? {|m| has_inspector_method?(meth, m) }
        set_arguments(mod, meth)
      end
    end

    # Method hook called during new_method_added
    def during_new_method_added(mod, meth); end

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

      args = mod.instance_method(meth).parameters.map do|(type, name)|
        case type
        when :rest then ["*#{name}"]
        when :req  then [name.to_s]
        when :opt  then [name.to_s, '']
        else nil
        end
      end.compact

      store[:args][meth.to_s] = args
    end

    # Hash of a module's method attributes i.e. descriptions, options by method
    # and then attribute
    def store(mod=@current_module)
      @mod_store[mod]
    end

    # Sets current module
    def current_module=(mod)
      @current_module = mod
      @mod_store[mod] ||= {}
    end

    # Determines if method's arguments should be scraped
    def has_inspector_method?(meth, inspector)
      true
    end
  end
end
