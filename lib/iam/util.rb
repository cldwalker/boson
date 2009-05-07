module Iam
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
  end
end