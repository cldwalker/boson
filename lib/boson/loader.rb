module Boson
  class LoadingDependencyError < StandardError; end
  class NoLibraryModuleError < StandardError; end
  class MultipleLibraryModulesError < StandardError; end
  class MethodConflictError < StandardError; end

  class Loader
    def self.load_and_create(library, options={})
      loader = library.is_a?(Module) ? LibraryLoader.new(library, options) : ( File.exists?(library_file(library.to_s)) ?
        FileLoader.new(library, options) : new(library, options) )
      loader.load
    rescue LoadingDependencyError=>e
      $stderr.puts e.message
      false
    rescue MethodConflictError=>e
      $stderr.puts e.message
      false
    end

    def self.library_file(library)
      File.join(Boson.dir, 'libraries', library + ".rb")
    end

    # Returns: true if loaded, false if failed, nil if already exists
    def initialize(library, options={})
      set_library(library)
      @options = options
      raise ArgumentError unless @library[:name]
      @name = @library[:name].to_s
      @library.merge!(:no_module_eval => @library.has_key?(:module))
    end

    def set_library(library)
      @library = Library.config_attributes(library)
    end

    def load_dependencies
      deps = []
      if !@library[:dependencies].empty?
        dependencies = @library[:dependencies]
        dependencies.each do |e|
          next if Library.loaded?(e)
          if (dep = Loader.load_and_create(e, @options))
            deps << dep
          else
            raise LoadingDependencyError, "Failed to load dependency #{e}"
          end
        end
      end
      @library[:created_dependencies] = deps
    end

    def load
      return nil if Library.loaded?(@name)
      load_dependencies
      load_main
      is_valid_library? && Library.new(@library.merge(:loaded=>true))
    rescue LoadingDependencyError, MethodConflictError
      raise
    rescue Exception
      $stderr.puts "Failed to load '#{library}'"
      $stderr.puts "Reason: #{$!}"
      $stderr.puts caller.slice(0,5).join("\n")
      false
    end

    def load_main
      detect_additions {
        Util.safe_require @name
        if @library[:module] && (lib_module = Util.constantize(@library[:module]))
          initialize_library_module(lib_module)
          @library[:module] = lib_module
        end
      }
    end

    def determine_lib_module(detected_modules)
      if @library[:module]
        raise InvalidLibraryModuleError unless (lib_module = Util.constantize(@library[:module]))
      else
        case detected_modules.size
        when 1 then lib_module = detected_modules[0]
        when 0 then raise NoLibraryModuleError
        else
          unless ((lib_module = Util.constantize("boson/libraries/#{@library[:name]}")) && lib_module.to_s[/^Boson::Libraries/])
            raise MultipleLibraryModulesError
          end
        end
      end
      lib_module
    end

    def is_valid_library?
      !(@library[:commands].empty? && @library[:gems].empty? && !@library.has_key?(:module))
    end

    def detect_additions(options={}, &block)
      options = {:record_detections=>true}.merge!(options)
      detected = Util.detect(options.merge(:detect_methods=>@library[:detect_methods]), &block)
      if options[:record_detections]
        add_gems_to_library(detected[:gems]) if detected[:gems]
        add_commands_to_library(detected[:methods])
      end
      detected
    end

    def add_gems_to_library(gems)
      @library.merge! :gems=>(@library[:gems] + gems)
    end

    def add_commands_to_library(commands)
      @library.merge! :commands=>(@library[:commands] + commands)
    end

    def initialize_library_module(lib_module)
      check_for_method_conflicts(lib_module)
      if @library[:object_command]
        create_object_command(lib_module)
      else
        Boson::Libraries.send :include, lib_module
        Boson::Libraries.send :extend_object, Boson.main_object
      end
      #td: eval in main_object without having to intrude with extend
      @library[:call_methods].each do |m|
        Boson.main_object.send m
      end
    end

    def check_for_method_conflicts(lib_module)
      return if @library[:force]
      conflicts = Util.common_instance_methods(lib_module, Boson::Libraries)
      unless conflicts.empty?
        raise MethodConflictError, "Can't load library because these methods conflict with existing libraries: #{conflicts.join(', ')}"
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

  class LibraryLoader < Loader
    def load_main
      detect_additions { initialize_library_module(@library[:module]) }
    end

    def set_library(library)
      @library = Library.config_attributes(Util.underscore(library)).merge!(:module=>library)
    end
  end

  class FileLoader < Loader
    def read_library(library_hash)
      library = library_hash[:name]
      if library_hash[:no_module_eval]
        Kernel.load self.class.library_file(library)
      else
        library_string = File.read(self.class.library_file(library))
        Libraries.module_eval(library_string, self.class.library_file(library))
      end
      $" << "libraries/#{library}.rb" unless $".include?("libraries/#{library}.rb")
    end

    def load_main
      detected = detect_additions(:modules=>true, :record_detections=>true) { read_library(@library) }
      lib_module = determine_lib_module(detected[:modules])
      detect_additions { initialize_library_module(lib_module) }
      @library[:module] = lib_module
    end
  end
end
