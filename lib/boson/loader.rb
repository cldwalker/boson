module Boson
  class LoadingDependencyError < StandardError; end
  class MethodConflictError < StandardError; end
  class InvalidLibraryModuleError < StandardError; end

  class Loader
    def self.load_library(library, options={})
      if (lib = load_and_create(library, options))
        lib.after_load
        puts "Loaded library #{lib[:name]}" if options[:verbose]
        lib[:created_dependencies].each do |e|
          e.after_load
          puts "Loaded library dependency #{e[:name]}" if options[:verbose]
        end
        true
      else
        false
      end
    end

    def self.load_and_create(library, options={})
      loader = library.is_a?(Module) ? ModuleLoader.new(library, options) : ( File.exists?(library_file(library.to_s)) ?
        FileLoader.new(library, options) : new(library, options) )
      return false if Library.loaded?(loader.name)
      result = loader.load
      $stderr.puts "Unable to load library #{loader.name}." if !result && !options[:dependency]
      result
    rescue LoadingDependencyError, MethodConflictError, InvalidLibraryModuleError =>e
      $stderr.puts "Unable to load library #{loader.name}. Reason: #{e.message}"
    rescue Exception
      $stderr.puts "Unable to load library #{loader.name}. Reason: #{$!}"
      $stderr.puts caller.slice(0,5).join("\n")
    end

    def self.library_file(library)
      File.join(Boson.dir, 'libraries', library + ".rb")
    end

    def initialize(library, options={})
      set_library(library)
      @options = options
      @name = @library[:name].to_s
    end
    attr_reader :name

    def set_library(library)
      @library = Library.config_attributes(library)
    end

    def load_dependencies
      deps = []
      if !@library[:dependencies].empty?
        dependencies = @library[:dependencies]
        dependencies.each do |e|
          next if Library.loaded?(e)
          if (dep = Loader.load_and_create(e, @options.merge(:dependency=>true)))
            deps << dep
          else
            raise LoadingDependencyError, "Can't load dependency #{e}"
          end
        end
      end
      @library[:created_dependencies] = deps
    end

    def load
      load_dependencies
      load_main
      is_valid_library? && Library.new(@library.merge(:loaded=>true))
    end

    def load_main
      detect_additions {
        Util.safe_require @name
        initialize_library_module
      }
    end

    def is_valid_library?
      !(@library[:commands].empty? && @library[:gems].empty? && !@library.has_key?(:module))
    end

    def detect_additions(options={}, &block)
      options = {:record_detections=>true}.merge!(options)
      detected = Util.detect(options.merge(:detect_methods=>@library[:detect_methods]), &block)
      if options[:record_detections]
        @library[:gems] += detected[:gems] if detected[:gems]
        @library[:commands] += detected[:methods]
      end
      detected
    end

    def initialize_library_module
      return unless @library[:module]
      lib_module = @library[:module] = Util.constantize(@library[:module]) ||
        raise(InvalidLibraryModuleError, "Module #{@library[:module]} doesn't exist")
      check_for_method_conflicts(lib_module)
      if @library[:object_command]
        create_object_command(lib_module)
      else
        Boson::Libraries.send :include, lib_module
        Boson::Libraries.send :extend_object, Boson.main_object
      end
      #td: eval in main_object without having to intrude with extend
      @library[:call_methods].each {|m| Boson.main_object.send m }
    end

    def check_for_method_conflicts(lib_module)
      return if @library[:force]
      conflicts = Util.common_instance_methods(lib_module, Boson::Libraries)
      unless conflicts.empty?
        raise MethodConflictError,
          "The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def create_object_command(lib_module)
      Libraries::ObjectCommands.create(@library[:name], lib_module)
      if (lib = Boson.libraries.find_by(:module=>Boson::Libraries::ObjectCommands))
        lib[:commands] << @library[:name]
        Boson.commands << Command.create(@library[:name], lib[:name])
        lib.create_command_aliases
      end
    end
  end

  class ModuleLoader < Loader
    def load_main
      detect_additions { initialize_library_module }
    end

    def set_library(library)
      @library = Library.config_attributes(Util.underscore(library)).merge!(:module=>library)
    end
  end

  class NoLibraryModuleError < StandardError; end
  class MultipleLibraryModulesError < StandardError; end

  class FileLoader < Loader
    def initialize(*args)
      super
      @library[:no_module_eval] = @library.has_key?(:module)
    end

    def read_library(library_hash)
      library = library_hash[:name]
      if library_hash[:no_module_eval]
        Kernel.load self.class.library_file(library)
      else
        library_string = File.read(self.class.library_file(library))
        Libraries.module_eval(library_string, self.class.library_file(library))
      end
    end

    def load_main
      detected = detect_additions(:modules=>true) { read_library(@library) }
      @library[:module] = determine_lib_module(detected[:modules]) unless @library[:module]
      detect_additions { initialize_library_module }
    end

    def determine_lib_module(detected_modules)
      case detected_modules.size
      when 1 then lib_module = detected_modules[0]
      when 0 then raise NoLibraryModuleError
      else
        unless ((lib_module = Util.constantize("boson/libraries/#{@library[:name]}")) && lib_module.to_s[/^Boson::Libraries/])
          raise MultipleLibraryModulesError
        end
      end
      lib_module
    end
  end
end