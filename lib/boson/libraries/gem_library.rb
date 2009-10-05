module Boson
  class GemLibrary < Library
    def self.is_a_gem?(name)
      Object.const_defined?(:Gem) && Gem.searcher.find(name).is_a?(Gem::Specification)
    end

    handles {|source| is_a_gem?(source.to_s) }

    def is_valid_library?
      !@gems.empty? || !@commands.empty? || !!@module
    end

    def load_source_and_set_module
      detect_additions { Util.safe_require @name }
    end
  end
end