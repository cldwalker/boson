module Boson
  class ModuleLibrary < Library
    handles {|source| source.is_a?(Module) }

    def reload; true; end

    def load_init
      super
      @module = @source
      underscore_lib = @source.to_s[/^Boson::Commands/] ? @source.to_s.split('::')[-1] : @source
      @name = Util.underscore(underscore_lib)
    end
  end
end