module Boson
  # This library takes a module as a library's name. Reload for this library
  # subclass is disabled.
  #
  # Example:
  #  >> load_library Math, :commands=>%w{sin cos tan}
  #  => true
  #
  #  # Let's brush up on ol trig
  #  >> sin (Math::PI/2)
  #  => 1.0
  #  >> tan (Math::PI/4)
  #  => 1.0
  #  # Close enough :)
  #  >> cos (Math::PI/2)
  #  => 6.12323399573677e-17

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
