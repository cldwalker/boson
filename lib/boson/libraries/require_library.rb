# This library requires the given name. This is useful for loading standard libraries,
# non-gem libraries (i.e. rip packages) and anything else in $LOAD_PATH.
class Boson::RequireLibrary < Boson::GemLibrary
  handles {|source|
    begin
      Kernel.load("#{source}.rb", true)
    rescue LoadError
      false
    end
  }
end