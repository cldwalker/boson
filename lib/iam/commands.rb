module Iam
  module Commands
    def commands(*args)
      puts Hirb::Helpers::Table.render(Iam.commands.search(*args), :fields=>[:name, :lib, :alias, :description])
    end

    def libraries(*args)
      puts Hirb::Helpers::Table.render(Iam.libraries.search(*args), :fields=>[:name, :loaded, :commands, :gems],
        :filters=>{:gems=>lambda {|e| e.join(',')}, :commands=>:size} )
    end
    
    def load_library(*args)
      Iam::Manager.load_library(*args)
    end
  end
end