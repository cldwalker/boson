module Iam
  module Commands
    def commands(*args)
      puts Hirb::Helpers::Table.render(Iam.commands.search(*args), :fields=>[:name, :lib, :alias, :description])
    end

    def libraries(*args)
      puts Hirb::Helpers::Table.render(Iam.libraries.search(*args), :fields=>[:name, :type, :loaded])
    end
    
    def load_library(*args)
      Iam::Manager.create_or_update_library(*args)
    end
  end
end