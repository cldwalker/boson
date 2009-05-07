module Iam
  class Manager
    extend Config
    class<<self
      def create_libraries(libraries, options={})
        libraries.each {|e|
          create_and_load_library(e, options)
        }
        library_names = Iam.libraries.map {|e| e[:name]}
        config[:libraries].each do |name, lib|
          unless library_names.include?(name)
            Iam.libraries << create_library(name)
          end
        end
      end

      def create_aliases
        aliases_hash = {}
        Iam.commands.each do |e|
          if e[:alias]
            if ((lib = Iam.libraries.detect {|l| l[:name] == e[:lib]}) && !lib[:module]) || !lib
              puts "No lib module for #{e[:name]} when aliasing"
              next
            end
            aliases_hash[lib[:module].to_s] ||= {}
            aliases_hash[lib[:module].to_s][e[:name]] = e[:alias]
          end
        end
        Alias.init {|c| c.instance_method = aliases_hash}
      end

      def create_and_load_library(*args)
        if (lib = load_library(*args)) && lib.is_a?(Library)
          Iam.libraries << lib
        end
      end

      def create_or_update_library(*args)
        if (lib = load_library(*args)) && lib.is_a?(Library)
          if (existing_lib = Iam.libraries.find {|e| e[:name] == lib[:name]})
            existing_lib.merge!(lib)
          else
            Iam.libraries << lib
          end
          puts "Loaded library #{lib[:name]}"
        end
      end

      def load_library(library, options={})
        lib = Library.load_and_create(library, options)
        add_lib_commands(lib)
        lib
      end

     def add_lib_commands(lib)
        if lib[:loaded]
          lib[:commands].each {|e| Iam.commands << create_command(e, lib[:name])}
        end
     end

      def create_library(*args)
        lib = Library.create(*args)
        add_lib_commands(lib)
        lib
      end

      def create_command(name, library=nil)
        (config[:commands][name] || {}).merge({:name=>name, :lib=>library.to_s})
      end
    end
  end
end
