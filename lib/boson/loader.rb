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
      detect_additions { load_module_commands } if @module || @class_commands
      @call_methods.each {|m| Boson.invoke m } unless @options[:index]
      is_valid_library? && (@loaded = true)
    end

    def load_dependencies
      @created_dependencies = @dependencies.map do |e|
        next if Library.loaded?(e)
        Library.load_once(e, @options.merge(:dependency=>true)) ||
          raise(LoadingDependencyError, "Can't load dependency #{e}")
      end.compact
    end

    def load_source_and_set_module; end

    def load_attributes
      {:gems=>[], :commands=>[], :call_methods=>[], :dependencies=>[], :detect_object_methods=>true}
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
      @detect_object_methods = true #reload_init
      reload_source_and_set_module
      detect_additions { load_module_commands } if @new_module
      @new_commands = @commands - original_commands
      true
    end

    def reload_source_and_set_module
      raise LoaderError, "Reload not implemented"
    end

    def detect_additions(options={}, &block)
      options.merge!(:detect_object_methods=>@detect_object_methods)
      detected = Util.detect(options, &block)
      @gems += detected[:gems] if detected[:gems]
      @commands += detected[:methods]
      detected
    end

    def initialize_library_module
      @module = @module ? Util.constantize(@module) : Util.create_module(Boson::Commands, @name[/\w+$/])
      raise(InvalidLibraryModuleError, "No module for library #{@name}") unless @module
      create_class_commands unless @class_commands.to_s.empty?
      check_for_method_conflicts unless @force
      if @namespace
        create_namespace_command
        @commands += Boson.invoke(namespace_command).commands
      else
        Boson::Universe.send :include, @module
        Boson::Universe.send :extend_object, Boson.main_object
      end
    end

    def create_class_commands
      Alias.manager.create_aliases(:class_to_instance_method, @module.to_s=>@class_commands.invert)
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