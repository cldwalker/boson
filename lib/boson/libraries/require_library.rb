class Boson::RequireLibrary < Boson::GemLibrary
  handles {|source|
    begin
      Kernel.load("#{source}.rb", true)
    rescue LoadError
      false
    end
  }
end