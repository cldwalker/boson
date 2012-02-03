module Boson
  # Base class for library loading errors. Raised mostly in Boson::Loader and
  # rescued by Boson::Manager.
  class LoaderError < StandardError; end

  # Handles loading of libraries and commands.
  class Manager
    # Loads a library or an array of libraries with options. Manager loads the
    # first library subclass to return true for Library#handles
    # ==== Examples:
    #   Manager.load MyRunner
    #
    # Any options that aren't listed here are passed as library attributes to
    # the libraries (see Library.new)
    # ==== Options:
    # [:verbose] Boolean to print each library's loaded status along with more verbose errors. Default is false.
    def self.load(libraries, options={})
      instance.load(libraries, options)
    end

    class <<self; attr_accessor :instance; end

    def self.instance
      @instance ||= new
    end

    # Adds a library to Boson.libraries
    def self.add_library(lib)
      Boson.libraries.delete(Boson.library(lib.name))
      Boson.libraries << lib
    end

    # Given a library name, determines if it's loaded
    def self.loaded?(lib_name)
      ((lib = Boson.library(lib_name)) && lib.loaded) ? true : false
    end

    attr_accessor :failed_libraries, :verbose
    def initialize
      @failed_libraries = []
    end

    def load(libraries, options={})
      Array(libraries).map {|e|
        (@library = load_once(e, options)) ? after_load : false
      }.all?
    end

    # Adds a library to the failed list
    def add_failed_library(library)
      failed_libraries << library
    end

    # Called after a library is loaded
    def after_load
      create_commands(@library)
      self.class.add_library(@library)
      puts "Loaded library #{@library.name}" if verbose
      during_after_load
      true
    end

    # Redefines commands
    def redefine_commands(lib, commands)
      option_commands = lib.command_objects(commands).select(&:option_command?)
      accepted, rejected = option_commands.partition {|e|
        e.args(lib) || e.arg_size }
      if verbose && rejected.size > 0
        puts "Following commands cannot have options until their arguments " +
          "are configured: " + rejected.map {|e| e.name}.join(', ')
      end
      accepted.each {|cmd| Scientist.redefine_command(lib.namespace_object, cmd) }
    end

    module API
      # Method hook for loading dependencies or anything else before loading
      # a library
      def load_dependencies(lib, options); end

      # Method hook in middle of after_load
      def during_after_load; end

      # Method hook called before create_commands
      def before_create_commands(lib)
        if lib.is_a?(RunnerLibrary) && lib.module
          Inspector.add_method_data_to_library(lib)
        end
      end

      # Method hook called after create_commands
      def after_create_commands(lib, commands); end

      # Handles an error from a load action
      def handle_load_action_error(library, load_method, err)
        case err
        when LoaderError
          add_failed_library library
          warn "Unable to #{load_method} library #{library}. Reason: #{err.message}"
        else
          add_failed_library library
          message = "Unable to #{load_method} library #{library}. Reason: #{err}"
          if Boson.debug
            message << "\n" + err.backtrace.map {|e| "  " + e }.join("\n")
          elsif verbose
            message << "\n" + err.backtrace.slice(0,3).map {|e| "  " + e }.join("\n")
          end
          warn message
        end
      end
    end
    include API

    private
    def call_load_action(library, load_method)
      yield
    rescue StandardError, SyntaxError, LoadError => err
      handle_load_action_error(library, load_method, err)
    ensure
      Inspector.disable if Inspector.enabled
    end

    def load_once(source, options={})
      self.verbose = options[:verbose]

      call_load_action(source, :load) do
        lib = loader_create(source, options)
        if self.class.loaded?(lib.name)
          if verbose && !options[:dependency]
            warn "Library #{lib.name} already exists."
          end
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
          warn "Library #{lib.name} did not load successfully."
        end
        warn "  "+lib.inspect if Boson.debug
        false
      end
    end

    def loader_create(source, options)
      options = options.dup.tap {|h| h.delete(:verbose) }
      lib_class = Library.handle_blocks.find {|k,v| v.call(source) } or
        raise(LoaderError, "Library #{source} not found.")
      lib_class[0].new(options.merge(name: source))
    end

    def create_commands(lib, commands=lib.commands)
      before_create_commands(lib)
      commands.each {|e| Boson.commands << Command.create(e, lib)}
      after_create_commands(lib, commands)
      redefine_commands(lib, commands)
    end
  end
end
