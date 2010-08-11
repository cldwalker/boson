module Boson
  # Base class for library loading errors. Raised mostly in Boson::Loader and rescued by Boson::Manager.
  class LoaderError < StandardError; end
  # Raised when a library's append_features returns false.
  class AppendFeaturesFalseError < StandardError; end

  # Handles loading of libraries and commands.
  class Manager
    class <<self
      attr_accessor :failed_libraries

      # Loads a library or an array of libraries with options. Manager loads the first library subclass
      # to meet a library subclass' criteria in this order: ModuleLibrary, FileLibrary, GemLibrary, RequireLibrary.
      # ==== Examples:
      #   Manager.load 'my_commands'  -> Loads a FileLibrary object from ~/.boson/commands/my_commands.rb
      #   Manager.load 'method_lister' -> Loads a GemLibrary object which requires the method_lister gem
      # Any options that aren't listed here are passed as library attributes to the libraries (see Library.new)
      # ==== Options:
      # [:verbose] Boolean to print each library's loaded status along with more verbose errors. Default is false.
      def load(libraries, options={})
        Array(libraries).map {|e|
          (@library = load_once(e, options)) ? after_load : false
        }.all?
      end

      #:stopdoc:
      def failed_libraries
        @failed_libraries ||= []
      end

      def add_library(lib)
        Boson.libraries.delete(Boson.library(lib.name))
        Boson.libraries << lib
      end

      def loaded?(lib_name)
        ((lib = Boson.library(lib_name)) && lib.loaded) ? true : false
      end

      def rescue_load_action(library, load_method)
        yield
      rescue AppendFeaturesFalseError
        warn "DEBUG: Library #{library} didn't load due to append_features" if Runner.debug
      rescue LoaderError=>e
        FileLibrary.reset_file_cache(library.to_s)
        failed_libraries << library
        $stderr.puts "Unable to #{load_method} library #{library}. Reason: #{e.message}"
      rescue StandardError, SyntaxError, LoadError =>e
        FileLibrary.reset_file_cache(library.to_s)
        failed_libraries << library
        message = "Unable to #{load_method} library #{library}. Reason: #{$!}"
        if Runner.debug
          message += "\n" + e.backtrace.map {|e| "  " + e }.join("\n")
        elsif @options[:verbose]
          message += "\n" + e.backtrace.slice(0,3).map {|e| "  " + e }.join("\n")
        end
        $stderr.puts message
      ensure
        Inspector.disable if Inspector.enabled
      end

      def load_once(source, options={})
        @options = options
        rescue_load_action(source, :load) do
          lib = loader_create(source)
          if loaded?(lib.name)
            $stderr.puts "Library #{lib.name} already exists" if options[:verbose] && !options[:dependency]
            false
          else
            if lib.load { load_dependencies(lib, options) }
              lib
            else
              $stderr.puts "Unable to load library #{lib.name}." if !options[:dependency]
              false
            end
          end
        end
      end

      def lib_dependencies
        @lib_dependencies ||= {}
      end

      def load_dependencies(lib, options={})
        lib_dependencies[lib] = Array(lib.dependencies).map do |e|
          next if loaded?(e)
          load_once(e, options.merge(:dependency=>true)) ||
            raise(LoaderError, "Can't load dependency #{e}")
        end.compact
      end

      def loader_create(source)
        lib_class = Library.handle_blocks.find {|k,v| v.call(source) } or raise(LoaderError, "Library #{source} not found.")
        lib_class[0].new(@options.merge(:name=>source))
      end

      def after_load
        create_commands(@library)
        add_library(@library)
        puts "Loaded library #{@library.name}" if @options[:verbose]
        (lib_dependencies[@library] || []).each do |e|
          create_commands(e)
          add_library(e)
          puts "Loaded library dependency #{e.name}" if @options[:verbose]
        end
        true
      end

      def before_create_commands(lib)
        lib.is_a?(FileLibrary) && lib.module && Inspector.add_method_data_to_library(lib)
      end

      def create_commands(lib, commands=lib.commands)
        before_create_commands(lib)
        commands.each {|e| Boson.commands << Command.create(e, lib)}
        create_command_aliases(lib, commands) if commands.size > 0 && !lib.no_alias_creation
        redefine_commands(lib, commands)
      end

      def redefine_commands(lib, commands)
        option_commands = lib.command_objects(commands).select {|e| e.option_command? }
        accepted, rejected = option_commands.partition {|e| e.args(lib) || e.arg_size }
        if @options[:verbose] && rejected.size > 0
          puts "Following commands cannot have options until their arguments are configured: " +
            rejected.map {|e| e.name}.join(', ')
        end
        accepted.each {|cmd| Scientist.redefine_command(lib.namespace_object, cmd) }
      end

      def create_command_aliases(lib, commands)
        lib.module ? prep_and_create_instance_aliases(commands, lib.module) : check_for_uncreated_aliases(lib, commands)
      end

      def prep_and_create_instance_aliases(commands, lib_module)
        aliases_hash = {}
        select_commands = Boson.commands.select {|e| commands.include?(e.name)}
        select_commands.each do |e|
          if e.alias
            aliases_hash[lib_module.to_s] ||= {}
            aliases_hash[lib_module.to_s][e.name] = e.alias
          end
        end
        create_instance_aliases(aliases_hash)
      end

      def create_instance_aliases(aliases_hash)
        Alias.manager.create_aliases(:instance_method, aliases_hash)
      end

      def create_class_aliases(mod, class_commands)
        class_commands.dup.each {|k,v|
          if v.is_a?(Array)
            class_commands.delete(k).each {|e| class_commands[e] = "#{k}.#{e}"}
          end
        }
        Alias.manager.create_aliases(:any_to_instance_method, mod.to_s=>class_commands.invert)
      end

      def check_for_uncreated_aliases(lib, commands)
        return if lib.is_a?(GemLibrary)
        if (found_commands = Boson.commands.select {|e| commands.include?(e.name)}) && found_commands.find {|e| e.alias }
          $stderr.puts "No aliases created for library #{lib.name} because it has no module"
        end
      end
      #:startdoc:
    end
  end
end