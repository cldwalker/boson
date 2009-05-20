module Boson
  module Util
    extend self
    #From Rails ActiveSupport
    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
       gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
       gsub(/([a-z\d])([A-Z])/,'\1_\2').
       tr("-", "_").
       downcase
    end

    # from Rails ActiveSupport
    def camelize(string)
      string.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
    end
    
    def constantize(string)
      any_const_get(camelize(string))
    end

    # Returns a constant like const_get() no matter what namespace it's nested in.
    # Returns nil if the constant is not found.
    def any_const_get(name)
      return name if name.is_a?(Module)
      begin
        klass = Object
        name.split('::').each {|e|
          klass = klass.const_get(e)
        }
        klass
      rescue
         nil
      end
    end

    def detect(options={}, &block)
      original_gems = Gem.loaded_specs.keys if Object.const_defined? :Gem
      original_object_methods = Object.instance_methods
      original_instance_methods = Boson.base_object.instance_eval("class<<self;self;end").instance_methods
      original_modules = modules if options[:modules]
      block.call
      detected = {}
      detected[:methods] = options[:detect_methods] ? (Object.instance_methods - original_object_methods + 
        Boson.base_object.instance_eval("class<<self;self;end").instance_methods - original_instance_methods).uniq :
        Object.instance_methods - original_object_methods
      detected[:gems] = Gem.loaded_specs.keys - original_gems if Object.const_defined? :Gem
      detected[:modules] = modules - original_modules if options[:modules]
      detected
    end

    def safe_require(lib)
      begin
        require lib
      rescue LoadError
        false
      end
    end

    def modules
      all_modules = []
      ObjectSpace.each_object(Module) {|e| all_modules << e}
      all_modules
    end
  end
end
