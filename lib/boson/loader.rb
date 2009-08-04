module Boson
  class LoadingDependencyError < StandardError; end
  class NoLibraryModuleError < StandardError; end
  class MultipleLibraryModulesError < StandardError; end
  class MethodConflictError < StandardError; end

  module Loader
    extend self
    def default_library
      {:loaded=>false, :detect_methods=>true, :gems=>[], :commands=>[], :except=>[], :call_methods=>[], :dependencies=>[], :force=>false}
    end

    def library_config(library=nil)
      @library_config ||= default_library.merge(:name=>library.to_s).merge!(Boson.config[:libraries][library.to_s] || {})
    end

    def reset_library_config; @library_config = nil; end

    def set_library_config(library, options={})
      if library.is_a?(Module)
        library_config(Util.underscore(library)).merge!(:module=>library)
      else
        library_config(library)
      end
      library_config.merge! options.dup.delete_if {|k,v| !library_config.has_key?(k)} unless options.empty?
      library_config.merge!(:no_module_eval => library_config.has_key?(:module))
    end

    # Returns: true if loaded, false if failed, nil if already exists
    def load_and_create(library, options={})
      set_library_config(library, options)
      return nil if library_loaded?(library_config[:name])
      load(library, options) && create(library_config[:name], :loaded=>true)
    rescue LoadingDependencyError=>e
      $stderr.puts e.message
      false
    rescue MethodConflictError=>e
      $stderr.puts e.message
      false
    ensure
      reset_library_config
    end

    def create(name, lib_hash={})
      library_obj = library_config(name).merge(lib_hash)
      set_library_commands(library_obj)
      reset_library_config
      Library.new(library_obj)
    end

    def set_library_commands(library_obj)
      aliases = library_obj[:commands].map {|e|
        Boson.config[:commands][e][:alias] rescue nil
      }.compact
      library_obj[:commands] -= aliases
      library_obj[:commands].delete(library_obj[:name]) if library_obj[:object_command]
    end

    def load_dependencies(library, options)
      deps = []
      if !library_config[:dependencies].empty?
        dependencies = library_config[:dependencies]
        reset_library_config
        dependencies.each do |e|
          next if library_loaded?(e)
          if (dep = load_and_create(e, options))
            deps << dep
          else
            raise LoadingDependencyError, "Failed to load dependency #{e}"
          end
        end
        set_library_config(library)
      end
      library_config[:created_dependencies] = deps
    end

    def load(library, options={})
      load_dependencies(library, options)
      if library.is_a?(Module)
        detect_additions { initialize_library_module(library) }
      else
        library = library.to_s
        if File.exists?(library_file(library))
          detected = detect_additions(:modules=>true, :record_detections=>true) { read_library(library_config) }
          lib_module = determine_lib_module(detected[:modules])
          detect_additions { initialize_library_module(lib_module) }
          library_config.merge!(:module=>lib_module)
        else
          detect_additions {
            Util.safe_require library.to_s
            initialize_library_module(lib_module) if library_config[:module] && (lib_module = Util.constantize(library_config[:module]))
          }
        end
      end
      is_valid_library?
    rescue LoadingDependencyError, MethodConflictError
      raise
    rescue Exception
      $stderr.puts "Failed to load '#{library}'"
      $stderr.puts "Reason: #{$!}"
      $stderr.puts caller.slice(0,5).join("\n")
      false
    end

    def read_library(library_hash)
      library = library_hash[:name]
      if library_hash[:no_module_eval]
        Kernel.load library_file(library)
      else
        library_string = File.read(library_file(library))
        Libraries.module_eval(library_string, library_file(library))
      end
      $" << "libraries/#{library}.rb" unless $".include?("libraries/#{library}.rb")
    end

    def determine_lib_module(detected_modules)
      if library_config[:module]
        raise InvalidLibraryModuleError unless (lib_module = Util.constantize(library_config[:module]))
      else
        case detected_modules.size
        when 1 then lib_module = detected_modules[0]
        when 0 then raise NoLibraryModuleError
        else
          unless ((lib_module = Util.constantize("boson/libraries/#{library_config[:name]}")) && lib_module.to_s[/^Boson::Libraries/])
            raise MultipleLibraryModulesError
          end
        end
      end
      lib_module
    end

    def is_valid_library?
      !(library_config[:commands].empty? && library_config[:gems].empty? && !library_config.has_key?(:module))
    end

    def library_file(library)
      File.join(Boson.dir, 'libraries', library + ".rb")
    end

    def detect_additions(options={}, &block)
      options = {:record_detections=>true}.merge!(options)
      detected = Util.detect(options.merge(:detect_methods=>library_config[:detect_methods]), &block)
      if options[:record_detections]
        add_gems_to_library_config(detected[:gems]) if detected[:gems]
        add_commands_to_library_config(detected[:methods])
      end
      detected
    end

    def add_gems_to_library_config(gems)
      library_config.merge! :gems=>(library_config[:gems] + gems)
    end

    def add_commands_to_library_config(commands)
      library_config.merge! :commands=>(library_config[:commands] + commands)
    end

    def initialize_library_module(lib_module)
      check_for_method_conflicts(lib_module)
      if library_config[:object_command]
        create_object_command(lib_module)
      else
        Boson::Libraries.send :include, lib_module
        Boson::Libraries.send :extend_object, Boson.main_object
      end
      #td: eval in main_object without having to intrude with extend
      library_config[:call_methods].each do |m|
        Boson.main_object.send m
      end
    end

    def check_for_method_conflicts(lib_module)
      return if library_config[:force]
      conflicts = Util.common_instance_methods(lib_module, Boson::Libraries)
      unless conflicts.empty?
        raise MethodConflictError, "Can't load library because these methods conflict with existing libraries: #{conflicts.join(', ')}"
      end
    end

    def create_object_command(lib_module)
      Libraries::ObjectCommands.create(library_config[:name], lib_module)
      # Manager.add_object_command(library_config[:name])
      if (lib = Boson.libraries.find_by(:module=>Boson::Libraries::ObjectCommands))
        lib[:commands] << library_config[:name]
        Boson.commands << Command.create(library_config[:name], lib[:name])
        lib.create_lib_aliases_or_warn
      end
    end

    def library_loaded?(lib_name)
      ((lib = Boson.libraries.find_by(:name=>lib_name)) && lib[:loaded]) ? true : false
    end
  end
end