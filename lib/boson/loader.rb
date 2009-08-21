module Boson
  class LoaderError < StandardError; end
  class LoadingDependencyError < LoaderError; end
  class MethodConflictError < LoaderError; end
  class InvalidLibraryModuleError < LoaderError; end

  module Loader
    def load
      load_init
      load_dependencies
      load_source
      detect_additions { initialize_library_module }
      is_valid_library? && (@loaded = true)
    end

    def load_dependencies
      @created_dependencies = @dependencies.map do |e|
        next if Library.loaded?(e)
        Library.load_once(e, :dependency=>true) ||
          raise(LoadingDependencyError, "Can't load dependency #{e}")
      end.compact
    end

    def load_source; end

    def load_attributes
      {:detect_methods=>true, :gems=>[], :commands=>[], :call_methods=>[], :dependencies=>[]}
    end

    def load_init
      set_attributes load_attributes.merge(@config)
    end

    def reload
      @detect_methods = true
      detected = detect_additions(:modules=>true) { reload_source }
      if !detected[:modules].empty?
        @module = determine_lib_module(detected[:modules])
        @commands = []
        detect_additions { initialize_library_module }
        Boson.commands.delete_if {|e| e.lib == @name }
      end
      create_commands(@commands)
      true
    end

    def reload_source
      raise LoaderError, "Reload not implemented"
    end

    def is_valid_library?
      !!@module
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
      if @object_command
        create_object_command
      else
        Boson::Libraries.send :include, @module
        Boson::Libraries.send :extend_object, Boson.main_object
      end
      @call_methods.each {|m| Boson.main_object.send m }
    end

    def check_for_method_conflicts
      return if @force
      conflicts = Util.common_instance_methods(@module, Boson::Libraries)
      unless conflicts.empty?
        raise MethodConflictError,"The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def create_object_command
      Libraries::ObjectCommands.create(@name, @module)
      if (lib = Boson.libraries.find_by(:module=>Boson::Libraries::ObjectCommands))
        lib.commands << @name
        Boson.commands << Command.create(@name, lib.name)
        lib.create_command_aliases
      end
    end
  end
end
