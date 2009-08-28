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
      detect_additions { load_module_commands } if @module
      @call_methods.each {|m| Boson.invoke m }
      is_valid_library? && (@loaded = true)
    end

    def quick_load
      load_init
      load_source_and_set_module
      detect_additions { load_module_commands } if @module
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

    def load_module_commands
        initialize_library_module
    rescue MethodConflictError=>e
      if Boson.config[:error_method_conflicts] || @namespace
        raise MethodConflictError, e.message
      else
        $stderr.puts "Unable to load library #{@name} into global namespace. Attempting load into the namespace #{namespace_command}."
        (@namespace = true) && initialize_library_module
      end
    end

    def is_valid_library?
      !!@module
    end

    def reload
      original_commands = @commands
      @detect_methods = true #reload_init
      reload_source_and_set_module
      detect_additions { initialize_library_module } if @new_module
      @new_commands = @commands - original_commands
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
      check_for_method_conflicts unless @force
      if @namespace
        create_namespace_command
        @commands += Boson.invoke(namespace_command).commands
      else
        Boson::Universe.send :include, @module
        Boson::Universe.send :extend_object, Boson.main_object
      end
    end

    def check_for_method_conflicts
      conflicts = @namespace ? (Boson.main_object.respond_to?(namespace_command) ? [namespace_command] : []) :
        Util.common_instance_methods(@module, Boson::Universe)
      unless conflicts.empty?
        raise MethodConflictError,"The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def namespace_command
      @namespace_command ||= @namespace.is_a?(String) ? @namespace : @name[/\w+$/]
    end

    def namespace_object
      @namespace_object ||= @namespace ? Boson.invoke(namespace_command) : Boson.main_object
    end

    def create_namespace_command
      Commands::Namespace.create(namespace_command, @module)
      if (lib = Boson.library(Boson::Commands::Namespace, :module))
        lib.commands << namespace_command
        lib.create_commands([namespace_command])
      end
    end
  end
end