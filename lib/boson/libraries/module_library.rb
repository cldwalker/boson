module Boson
  # A library which takes a module as a library's name. Reload for this library
  # subclass is disabled.
  class ModuleLibrary < Library
    #:stopdoc:
    handles {|source| source.is_a?(Module) }

    def set_name(name)
      @module = name
      underscore_lib = name.to_s[/^Boson::Commands/] ? name.to_s.split('::')[-1] : name.to_s
      super Util.underscore(underscore_lib)
    end

    def reload; false; end
    #:startdoc:
  end
end