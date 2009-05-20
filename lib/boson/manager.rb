module Boson
  class Manager
    extend Config
    class<<self
      def load_libraries(libraries, options={})
        libraries.each {|e| load_library(e, options) }
      end

      def create_libraries(libraries, options={})
        libraries.each {|e| add_library(create_library(e)) }
      end

      def create_config_libraries
        config[:libraries].each do |name, lib|
          add_library(create_library(name))
        end
      end

      def create_library(*args)
        lib = Library.create(*args)
        add_lib_commands(lib)
        lib
      end

      def load_library(library, options={})
        if (lib = Library.load_and_create(library, options))
          add_library(lib)
          add_lib_commands(lib)
          puts "Loaded library #{lib[:name]}"
          lib[:created_dependencies].each do |e|
            add_library(e)
            add_lib_commands(e)
            puts "Loaded library dependency #{e[:name]}"
          end
          true
        else
          puts "Unable to load library #{library}"
          false
        end
      end

      def create_lib_aliases(commands, lib_module)
        aliases_hash = {}
        select_commands = Boson.commands.select {|e| commands.include?(e[:name])}
        select_commands.each do |e|
          if e[:alias]
            aliases_hash[lib_module.to_s] ||= {}
            aliases_hash[lib_module.to_s][e[:name]] = e[:alias]
          end
        end
        Alias.manager.create_aliases(:instance_method, aliases_hash)
      end

      def create_lib_aliases_or_warn(lib)
        if lib[:module]
          create_lib_aliases(lib[:commands], lib[:module])
        else
          if (commands = Boson.commands.select {|e| lib[:commands].include?(e[:name])}) && commands.find {|e| e[:alias]}
            puts "No aliases created for lib #{lib[:name]} because there is no lib module"
          end
        end
      end

      def library_loaded?(lib_name)
        ((lib = Boson.libraries.find {|e| e[:name] == lib_name}) && lib[:loaded]) ? true : false
      end

      def add_library(lib)
        if (existing_lib = Boson.libraries.find {|e| e[:name] == lib[:name]})
          existing_lib.merge!(lib)
        else
          Boson.libraries << lib
        end
      end

      def add_object_command(obj_command)
        if (lib = Boson.libraries.find {|e| e[:module] == Boson::ObjectCommands})
          lib[:commands] << obj_command
          Boson.commands << create_command(obj_command, lib[:name])
          create_lib_aliases_or_warn(lib)
        end
      end

      def add_lib_commands(lib)
        if lib[:loaded]
          if lib[:except]
            lib[:commands] -= lib[:except]
            lib[:except].each {|e| Boson.base_object.instance_eval("class<<self;self;end").send :undef_method, e }
          end
          lib[:commands].each {|e| Boson.commands << create_command(e, lib[:name])}
          if lib[:commands].size > 0
            create_lib_aliases_or_warn(lib)
          end
        end
      end

      def create_command(name, library=nil)
        (config[:commands][name] || {}).merge({:name=>name, :lib=>library.to_s})
      end
    end
  end
end
