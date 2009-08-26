module Boson
  module Commands
    module Core
      def commands(*args)
        render Boson.commands.search(*args).map {|e| e.to_hash}, :fields=>[:name, :lib, :alias, :description]
      end

      def libraries(query=nil)
        render Boson.libraries.search(query, :loaded=>true).map {|e| e.to_hash},
         :fields=>[:name, :loaded, :commands, :gems], :filters=>{:gems=>lambda {|e| e.join(',')}, :commands=>:size}
      end
    
      def load_library(library, options={})
        Boson::Library.load_library(library, {:verbose=>true}.merge!(options))
      end

      def reload_library(name, options={})
        Boson::Library.reload_library(name, {:verbose=>true}.merge!(options))
      end

      def render(object, options={})
        options[:class] = options.delete(:as) || :auto_table
        ::Hirb::Console.render_output(object, options)
      end

      def menu(output, options={}, &block)
        ::Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
      end
    end
  end
end
