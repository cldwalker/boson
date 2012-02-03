module Boson
  # Gathers method attributes by redefining method_added and capturing method
  # calls before a method.
  class MethodInspector
    METHODS = [:config, :desc, :options]
    SCRAPEABLE_METHODS = [:options]
    METHOD_CLASSES = {:config=>Hash, :desc=>String, :options=>Hash}
    ALL_METHODS = METHODS + [:option]

    def self.safe_new_method_added(mod, meth)
      return unless mod.to_s[/^Boson::Commands::/]
      new_method_added(mod, meth)
    end

    def self.new_method_added(mod, meth)
      instance.new_method_added(mod, meth)
    end

    class << self; attr_accessor :instance end

    def self.instance
      @instance ||= new
    end

    (METHODS + [:option, :mod_store]).each do |meth|
      define_singleton_method(meth) do |*args|
        instance.send(meth, *args)
      end
    end

    attr_accessor :current_module, :mod_store
    def initialize
      @mod_store = {}
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

    # Hash of a module's method attributes i.e. descriptions, options by method
    # and then attribute
    def store(mod=@current_module)
      @mod_store[mod]
    end

    # Renames store key from old to new name
    def rename_store_key(old, new)
      mod_store[new] = mod_store.delete old
    end

    # Sets current module
    def current_module=(mod)
      @current_module = mod
      @mod_store[mod] ||= {}
    end

    module API
      # Method hook called during new_method_added
      def during_new_method_added(mod, meth); end

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

      # Determines if method's arguments should be scraped
      def has_inspector_method?(meth, inspector)
        true
      end
    end
    include API
  end
end
