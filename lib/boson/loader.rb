module Boson
  class LoaderError < StandardError; end
  class LoadingDependencyError < LoaderError; end
  class MethodConflictError < LoaderError; end
  class InvalidLibraryModuleError < LoaderError; end

  module Loader
    def load
      load_init
      load_dependencies
      load_source_and_set_module
      detect_additions { initialize_library_module } if @module
      @call_methods.each {|m| Boson.main_object.send m }
      is_valid_library? && (@loaded = true)
    end

    def load_dependencies
      @created_dependencies = @dependencies.map do |e|
        next if Library.loaded?(e)
        Library.load_once(e, :dependency=>true) ||
          raise(LoadingDependencyError, "Can't load dependency #{e}")
      end.compact
    end

    def load_source_and_set_module; end

    def load_attributes
      {:detect_methods=>true, :gems=>[], :commands=>[], :call_methods=>[], :dependencies=>[]}
    end

    def load_init
      set_attributes load_attributes.merge(@config)
    end

    def is_valid_library?
      !!@module
    end

    def reload
      @detect_methods = true #reload_init
      reload_source_and_set_module
      detect_additions { initialize_library_module } if @new_module
      true
    end

    def reload_source_and_set_module
      raise LoaderError, "Reload not implemented"
    end

    def detect_additions(options={}, &block)
      options = {:record_detections=>true}.merge!(options)
      detected = Util.detect(options.merge(:detect_methods=>@detect_methods), &block)
      if options[:record_detections]
        @gems += detected[:gems] if detected[:gems]
        @commands += detected[:methods]
      end
      detected
    end

    def initialize_library_module
      @module = Util.constantize(@module) || raise(InvalidLibraryModuleError, "Module #{@module} doesn't exist")
      check_for_method_conflicts
      if @namespace
        create_namespace_command
      else
        Boson::Commands.send :include, @module
        Boson::Commands.send :extend_object, Boson.main_object
      end
    end

    def check_for_method_conflicts
      return if @force
      conflicts = Util.common_instance_methods(@module, Boson::Commands)
      unless conflicts.empty?
        raise MethodConflictError,"The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def create_namespace_command
      command_name = @namespace.is_a?(String) ? @namespace : @name[/\w+$/]
      Commands::Namespace.create(command_name, @module)
      if (lib = Boson.libraries.find_by(:module=>Boson::Commands::Namespace))
        lib.commands << command_name
        Boson.commands << Command.create(command_name, lib.name)
        lib.create_command_aliases
      end
    end
  end
end
