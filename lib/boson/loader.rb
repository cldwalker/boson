module Boson
  class AppendFeaturesFalseError < StandardError; end
  class MethodConflictError < LoaderError; end
  class InvalidLibraryModuleError < LoaderError; end

  module Loader
    def load
      @gems ||= []
      load_source_and_set_module
      module_callbacks if @module
      yield if block_given?
      (@module || @class_commands) ? detect_additions { load_module_commands } : @namespace = nil
      @init_methods.each {|m| namespace_object.send(m) if namespace_object.respond_to?(m) } if @init_methods && !@index
      set_library_commands
      is_valid_library? && (@loaded = true)
    end

    def load_source_and_set_module; end

    def module_callbacks
      set_config(@module.config) if @module.respond_to?(:config)
      if @module.respond_to?(:append_features)
        raise AppendFeaturesFalseError unless @module.append_features(Module.new)
      end
    end

    def load_module_commands
        initialize_library_module
    rescue MethodConflictError=>e
      if Boson.repo.config[:error_method_conflicts] || @namespace
        raise MethodConflictError, e.message
      else
        @namespace = clean_name
        $stderr.puts "#{e.message}. Attempting load into the namespace #{@namespace}..."
        initialize_library_module
      end
    end

    def is_valid_library?
      !!@module
    end

    def reload
      original_commands = @commands
      reload_source_and_set_module
      detect_additions { load_module_commands } if @new_module
      @new_commands = @commands - original_commands
      true
    end

    def reload_source_and_set_module
      raise LoaderError, "Reload not implemented"
    end

    def detect_additions(options={}, &block)
      options[:object_methods] = @object_methods if !@object_methods.nil?
      detected = Util.detect(options, &block)
      @gems += detected[:gems] if detected[:gems]
      @commands += detected[:methods]
      detected
    end

    def initialize_library_module
      @module = @module ? Util.constantize(@module) : Util.create_module(Boson::Commands, clean_name)
      raise(InvalidLibraryModuleError, "No module for library #{@name}") unless @module
      Manager.create_class_aliases(@module, @class_commands) unless @class_commands.to_s.empty?
      check_for_method_conflicts unless @force
      @namespace = clean_name if @object_namespace
      @namespace ? Namespace.create(@namespace, self) : include_in_universe
    end

    def include_in_universe(lib_module=@module)
      Boson::Universe.send :include, lib_module
      Boson::Universe.send :extend_object, Boson.main_object
    end

    def check_for_method_conflicts
      conflicts = @namespace ? (Boson.main_object.respond_to?(@namespace) ? [@namespace] : []) :
        Util.common_instance_methods(@module, Boson::Universe)
      unless conflicts.empty?
        raise MethodConflictError,"The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def set_library_commands
      aliases = @commands.map {|e|
        @commands_hash[e][:alias] rescue nil
      }.compact
      @commands -= aliases
      @commands.delete(@namespace) if @namespace && !namespace_object.object_delegate?
      @commands += Boson.invoke(@namespace).boson_commands if @namespace
      @commands -= @except if @except
    end
  end
end