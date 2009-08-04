module Boson
  module Libraries
    module Core
      def commands(*args)
        puts ::Hirb::Helpers::Table.render(Boson.commands.search(*args), :fields=>[:name, :lib, :alias, :description])
      end

      def libraries(query=nil)
        puts ::Hirb::Helpers::Table.render(Boson.libraries.search(query, :loaded=>true), :fields=>[:name, :loaded, :commands, :gems],
          :filters=>{:gems=>lambda {|e| e.join(',')}, :commands=>:size} )
      end
    
      def load_library(library, options={})
        Boson::Library.load_library(library, {:verbose=>true}.merge!(options))
      end

      def reload_library(name)
        if (lib = Boson.libraries.search(:name=>name)[0])
          Boson::Loader.read_library(lib)
        end
      end
    end
  end
end
