module Boson
  module Commands
    def commands(*args)
      puts Hirb::Helpers::Table.render(Boson.commands.search(*args), :fields=>[:name, :lib, :alias, :description])
    end

    def libraries(*args)
      puts Hirb::Helpers::Table.render(Boson.libraries.search(*args), :fields=>[:name, :loaded, :commands, :gems],
        :filters=>{:gems=>lambda {|e| e.join(',')}, :commands=>:size} )
    end
    
    def load_library(*args)
      Boson::Manager.load_library(*args)
    end
  end
end
