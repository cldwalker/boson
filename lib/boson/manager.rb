module Boson
  # Base class for library loading errors. Raised mostly in Boson::Loader and rescued by Boson::Manager.
  class LoaderError < StandardError; end
  # Raised when a library's append_features returns false.
  class AppendFeaturesFalseError < StandardError; end

  # Handles loading of libraries and commands.
  class Manager
    module API
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
        warn "DEBUG: Library #{library} didn't load due to append_features" if Boson.debug
      rescue LoaderError=>e
        add_failed_library library
        $stderr.puts "Unable to #{load_method} library #{library}. Reason: #{e.message}"
      rescue StandardError, SyntaxError, LoadError =>e
        add_failed_library library
        message = "Unable to #{load_method} library #{library}. Reason: #{$!}"
        if Boson.debug
          message += "\n" + e.backtrace.map {|e| "  " + e }.join("\n")
        elsif @options[:verbose]
          message += "\n" + e.backtrace.slice(0,3).map {|e| "  " + e }.join("\n")
        end
        $stderr.puts message
      ensure
        Inspector.disable if Inspector.enabled
      end

      def add_failed_library(library)
        failed_libraries << library
      end

      def load_once(source, options={})
        @options = options
        rescue_load_action(source, :load) do
          lib = loader_create(source)
          if loaded?(lib.name)
            $stderr.puts "Library #{lib.name} already exists." if options[:verbose] && !options[:dependency]
            false
          else
            actual_load_once lib, options
          end
        end
      end

      def actual_load_once(lib, options)
        if lib.load { load_dependencies(lib, options) }
          lib
        else
          if !options[:dependency]
            $stderr.puts "Library #{lib.name} did not load successfully."
          end
          $stderr.puts "  "+lib.inspect if Boson.debug
          false
        end
      end

      def load_dependencies(lib, options)
      end

      def loader_create(source)
        lib_class = Library.handle_blocks.find {|k,v| v.call(source) } or raise(LoaderError, "Library #{source} not found.")
        lib_class[0].new(@options.merge(:name=>source))
      end

      def after_load
        create_commands(@library)
        add_library(@library)
        puts "Loaded library #{@library.name}" if @options[:verbose]
        during_after_load
        true
      end

      def during_after_load
      end

      def before_create_commands(lib)
        if lib.is_a?(RunnerLibrary) && lib.module
          Inspector.add_method_data_to_library(lib)
        end
      end

      def create_commands(lib, commands=lib.commands)
        before_create_commands(lib)
        commands.each {|e| Boson.commands << Command.create(e, lib)}
        after_create_commands(lib, commands)
        redefine_commands(lib, commands)
      end

      def after_create_commands(lib, commands)
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
      #:startdoc:
    end
    extend API
  end
end
