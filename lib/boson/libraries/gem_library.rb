module Boson
  # This library loads a gem by the given name. Unlike FileLibrary or ModuleLibrary, this library
  # doesn't need a module to provide its functionality.
  #
  # Example:
  #   >> load_library 'httparty', :class_commands=>{'put'=>'HTTParty.put',
  #      'delete'=>'HTTParty.delete' }
  #   => true
  #   >> put 'http://someurl.com'
  class GemLibrary < Library
    #:stopdoc:
    def self.is_a_gem?(name)
      return false unless defined? Gem
      Gem::VERSION >= '1.8.0' ?
        Gem::Specification.find_all_by_name(name)[0].is_a?(Gem::Specification) :
        Gem.searcher.find(name).is_a?(Gem::Specification)
    end

    handles {|source| is_a_gem?(source.to_s) }

    def loaded_correctly?
      !@gems.empty? || !@commands.empty? || !!@module
    end

    def load_source_and_set_module
      detect_additions { Util.safe_require @name }
    end
    #:startdoc:
  end
end
