module Boson
  module Commands
    def commands(*args)
      puts Hirb::Helpers::Table.render(Boson.commands.search(*args), :fields=>[:name, :lib, :alias, :description])
    end

    def libraries(*args)
      puts Hirb::Helpers::Table.render(Boson.libraries.search(*args), :fields=>[:name, :loaded, :commands, :gems],
        :filters=>{:gems=>lambda {|e| e.join(',')}, :commands=>:size} )
    end
    
    def load_library(libraries, options={})
      Boson::Manager.load_library(libraries, {:verbose=>true}.merge!(options))
    end

    def reload_library(name)
      if (lib = Boson.libraries.search(:name=>name)[0])
        Boson::Library.read_library(lib)
      end
    end
  end
end
