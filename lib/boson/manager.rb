module Boson
  class Manager
    class<<self
      def init(options={})
        $:.unshift Boson.dir unless $:.include? File.expand_path(Boson.dir)
        $:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
        Boson.main_object.extend Libraries
        create_initial_libraries(options)
        load_default_libraries(options)
        @initialized = true
      end

      def load_default_libraries(options)
        defaults = [Boson::Libraries::Core, Boson::Libraries::ObjectCommands]
        defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
        defaults += Boson.config[:defaults] if Boson.config[:defaults]
        load_libraries(defaults)
      end

      def create_initial_libraries(options)
        detected_libraries = Dir[File.join(Boson.dir, 'libraries', '**/*.rb')].map {|e| e.gsub(/.*libraries\//,'').gsub('.rb','') }
        libs = (detected_libraries + Boson.config[:libraries].keys).uniq
        create_libraries(libs, options)
      end

      def activate(options={})
        init(options) unless @initialized
        libraries = options[:libraries] || []
        load_libraries(libraries, options)
      end

      def load_libraries(libraries, options={})
        libraries.each {|e| load_library(e, options) }
      end

      def create_libraries(libraries, options={})
        libraries.each {|e| create_library(e).add_library }
      end

      def create_library(*args)
        lib = Loader.create(*args)
        lib.add_lib_commands
        lib
      end

      def load_library(library, options={})
        if (lib = Loader.load_and_create(library, options))
          lib.add_library
          lib.add_lib_commands
          puts "Loaded library #{lib[:name]}" if options[:verbose]
          lib[:created_dependencies].each do |e|
            e.add_library
            e.add_lib_commands
            puts "Loaded library dependency #{e[:name]}" if options[:verbose]
          end
          true
        else
          $stderr.puts "Unable to load library #{library}" if lib.is_a?(FalseClass)
          false
        end
      end
    end
  end
end