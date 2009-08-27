module Boson
  class ReplRunner < Runner
    class <<self
      def activate(options={})
        init(options) unless @initialized
        libraries = options[:libraries] || []
        Library.load(libraries, options)
      end

      def init(options={})
        Library.create all_libraries, options
        super
        load_default_libraries(options)
        @initialized = true
      end

      def load_default_libraries(options)
        defaults = boson_libraries
        defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
        defaults += Boson.config[:defaults]
        Library.load(defaults, options)
      end
    end
  end
end
  