module Boson
  class ModuleLibrary < Library
    handles {|source| source.is_a?(Module) }

    def reload; false; end

    def load_source_and_set_module
      @module = @source
      underscore_lib = @source.to_s[/^Boson::Commands/] ? @source.to_s.split('::')[-1] : @source
      @name = Util.underscore(underscore_lib)
    end
  end
end