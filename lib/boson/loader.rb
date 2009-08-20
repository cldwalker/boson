module Boson
  class LoaderError < StandardError; end
  class LoadingDependencyError < LoaderError; end
  class MethodConflictError < LoaderError; end
  class InvalidLibraryModuleError < LoaderError; end

  class Library
    def self.default_attributes
      {:detect_methods=>true, :gems=>[], :commands=>[], :call_methods=>[], :dependencies=>[]}
    end

    def config_attributes(lib)
      @obj = self #Library.new(:name=>lib.to_s)
      self.class.default_attributes.merge(:name=>lib.to_s).merge!(@obj.config)
    end

    # ==== Options:
    # [:verbose] Prints the status of each library as its loaded. Default is false.
    def self.load_library(library, options={})
      if (lib = load_once(library, options))
        lib.after_load
        puts "Loaded library #{lib.name}" if options[:verbose]
        lib.created_dependencies.each do |e|
          e.after_load
          puts "Loaded library dependency #{e.name}" if options[:verbose]
        end
        true
      else
        false
      end
    end

    def self.reload_library(library, options={})
      if (lib = Boson.libraries.find_by(:name=>library))
        if lib.loaded
          command_size = Boson.commands.size
          if (result = reload_existing(lib))
            puts "Reloaded library #{library}: Added #{Boson.commands.size - command_size} commands" if options[:verbose]
          end
          result
        else
          puts "Library hasn't been loaded yet. Loading library #{library}..." if options[:verbose]
          load_library(library, options)
        end
      else
        puts "Library #{library} doesn't exist." if options[:verbose]
        false
      end
    end

    def self.is_a_gem?(name)
      Gem.searcher.find(name).is_a?(Gem::Specification)
    end

    def self.create_with_loader(library, options={})
      lib = library.is_a?(Module) ? ModuleLibrary.new(:name=>library.to_s) : ( File.exists?(library_file(library.to_s)) ?
        FileLibrary.new(:name=>library.to_s) : (is_a_gem?(library) ? GemLibrary.new(:name=>library.to_s) :
        raise(LoaderError, "Library #{library} not found.") ) )
      lib.load_init(library, options)
      lib
    end

    def self.reload_existing(library)
      rescue_loader(library.name, :reload) do
        loader = create_with_loader(library.name)
        loader.reload
        if loader.library[:new_module]
          library.module = loader.library[:module]
          Boson.commands.delete_if {|e| e.lib == library.name }
        end
        library.create_commands(loader.library[:commands])
        true
      end
    end

    def self.rescue_loader(library, load_method)
      yield
    rescue LoaderError=>e
      $stderr.puts "Unable to #{load_method} library #{library}. Reason: #{e.message}"
    rescue Exception
      $stderr.puts "Unable to #{load_method} library #{library}. Reason: #{$!}"
      $stderr.puts caller.slice(0,5).join("\n")
    end

    def self.load_once(library, options={})
      rescue_loader(library, :load) do
        loader = create_with_loader(library, options)
        if Library.loaded?(loader.name)
          puts "Library #{loader.name} already exists" if options[:verbose] && !options[:dependency]
          false
        else
          result = loader.load
          $stderr.puts "Unable to load library #{loader.name}." if !result && !options[:dependency]
          result
        end
      end
    end

    def self.library_file(library)
      File.join(Boson.dir, 'libraries', library + ".rb")
    end

    def load_init(library, options={})
      set_library(library)
      @options = options
      @name = @library[:name].to_s
    end
    attr_reader :name, :library

    def set_library(library)
      @library = config_attributes(library)
    end

    def load_dependencies
      @library[:created_dependencies] = @library[:dependencies].map do |e|
        next if Library.loaded?(e)
        Library.load_once(e, @options.merge(:dependency=>true)) ||
          raise(LoadingDependencyError, "Can't load dependency #{e}")
      end.compact
    end

    def load
      load_dependencies
      load_source
      detect_additions { initialize_library_module }
      is_valid_library? && Library.loader_create(@library, @obj)
    end

    def load_source; end

    def reload
      detected = detect_additions(:modules=>true) { reload_source }
      if (@library[:new_module] = !detected[:modules].empty?)
        @library[:module] = determine_lib_module(detected[:modules])
        detect_additions { initialize_library_module }
      end
    end

    def reload_source
      raise LoaderError, "Reload not implemented"
    end

    def is_valid_library?
      @library.has_key?(:module)
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
      lib_module = @library[:module] = Util.constantize(@library[:module]) ||
        raise(InvalidLibraryModuleError, "Module #{@library[:module]} doesn't exist")
      check_for_method_conflicts(lib_module)
      if @library[:object_command]
        create_object_command(lib_module)
      else
        Boson::Libraries.send :include, lib_module
        Boson::Libraries.send :extend_object, Boson.main_object
      end
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
        lib.commands << @library[:name]
        Boson.commands << Command.create(@library[:name], lib.name)
        lib.create_command_aliases
      end
    end
  end

  class GemLibrary < Library
    def initialize_library_module
      super if @library[:module]
    end

    def is_valid_library?
      !@library[:gems].empty? || !@library[:commands].empty? || @library.has_key?(:module)
    end

    def load_source
      detect_additions { Util.safe_require @name }
    end
  end

  class ModuleLibrary < Library
    def reload; end

    def set_library(library)
      underscore_lib = library.to_s[/^Boson::Libraries/] ? library.to_s.split('::')[-1] : library
      @library = config_attributes(Util.underscore(underscore_lib)).merge!(:module=>library)
    end
  end

  class FileLibrary < Library
    def load_init(*args)
      super
      @library[:no_module_eval] ||= @library.has_key?(:module)
    end

    def read_library
      if @library[:no_module_eval]
        Kernel.load self.class.library_file(@name)
      else
        library_string = File.read(self.class.library_file(@name))
        Libraries.module_eval(library_string, self.class.library_file(@name))
      end
    end

    def load_source
      detected = detect_additions(:modules=>true) { read_library }
      @library[:module] = determine_lib_module(detected[:modules]) unless @library[:module]
    end

    def reload_source; read_library; end

    def determine_lib_module(detected_modules)
      case detected_modules.size
      when 1 then lib_module = detected_modules[0]
      when 0 then raise LoaderError, "Can't detect module. Make sure at least one module is defined in the library."
      else
        unless ((lib_module = Util.constantize("boson/libraries/#{@library[:name]}")) && lib_module.to_s[/^Boson::Libraries/])
          raise LoaderError, "Can't detect module. Specify a module in this library's config."
        end
      end
      lib_module
    end
  end
end