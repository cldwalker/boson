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
      is_valid_library? && transfer_loader(@loader)
    end

    def load_dependencies
      @loader[:created_dependencies] = @loader[:dependencies].map do |e|
        next if Library.loaded?(e)
        Library.load_once(e, :dependency=>true) ||
          raise(LoadingDependencyError, "Can't load dependency #{e}")
      end.compact
    end

    def load_source; end

    def load_init
      @loader = create_loader
      @name = @loader[:name].to_s
    end

    def transfer_loader(loader)
      valid_attributes = [:call_methods, :except, :module, :gems, :commands, :dependencies, :created_dependencies]
      loader.delete_if {|k,v| !valid_attributes.include?(k) }
      set_attributes loader.merge(:loaded=>true)
      set_library_commands
      self
    end

    def create_loader
      loader_attributes = {:detect_methods=>true, :gems=>[], :commands=>[], :call_methods=>[], :dependencies=>[]}
      loader_attributes.merge(:name=>@name).merge!(@config)
    end

    def reload
      @loader[:detect_methods] = true
      detected = detect_additions(:modules=>true) { reload_source }
      if !detected[:modules].empty?
        @loader[:module] = determine_lib_module(detected[:modules])
        @commands.each {|e| @loader[:commands].delete(e) } #td: fix hack
        detect_additions { initialize_library_module }
        Boson.commands.delete_if {|e| e.lib == @name }
        @module = @loader[:module]
      end
      create_commands(@loader[:commands])
      true
    end

    def reload_source
      raise LoaderError, "Reload not implemented"
    end

    def is_valid_library?
      @loader.has_key?(:module)
    end

    def detect_additions(options={}, &block)
      options = {:record_detections=>true}.merge!(options)
      detected = Util.detect(options.merge(:detect_methods=>@loader[:detect_methods]), &block)
      if options[:record_detections]
        @loader[:gems] += detected[:gems] if detected[:gems]
        @loader[:commands] += detected[:methods]
      end
      detected
    end

    def initialize_library_module
      lib_module = @loader[:module] = Util.constantize(@loader[:module]) ||
        raise(InvalidLibraryModuleError, "Module #{@loader[:module]} doesn't exist")
      check_for_method_conflicts(lib_module)
      if @loader[:object_command]
        create_object_command(lib_module)
      else
        Boson::Libraries.send :include, lib_module
        Boson::Libraries.send :extend_object, Boson.main_object
      end
      @loader[:call_methods].each {|m| Boson.main_object.send m }
    end

    def check_for_method_conflicts(lib_module)
      return if @loader[:force]
      conflicts = Util.common_instance_methods(lib_module, Boson::Libraries)
      unless conflicts.empty?
        raise MethodConflictError,
          "The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def create_object_command(lib_module)
      Libraries::ObjectCommands.create(@loader[:name], lib_module)
      if (lib = Boson.libraries.find_by(:module=>Boson::Libraries::ObjectCommands))
        lib.commands << @loader[:name]
        Boson.commands << Command.create(@loader[:name], lib.name)
        lib.create_command_aliases
      end
    end
  end
end
