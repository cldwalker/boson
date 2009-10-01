module Boson
  class LoaderError < StandardError; end
  class AppendFeaturesFalseError < StandardError; end
  class LoadingDependencyError < LoaderError; end
  class MethodConflictError < LoaderError; end
  class InvalidLibraryModuleError < LoaderError; end

  module Loader
    def load
      @gems ||= []
      load_source_and_set_module
      module_callbacks if @module
      load_dependencies
      detect_additions { load_module_commands } if @module || @class_commands
      @init_methods.each {|m| namespace_object.send(m) if namespace_object.respond_to?(m) } if @init_methods && !@options[:index]
      is_valid_library? && (@loaded = true)
    end

    def load_dependencies
      @created_dependencies = (@dependencies || []).map do |e|
        next if Library.loaded?(e)
        Library.load_once(e, @options.merge(:dependency=>true)) ||
          raise(LoadingDependencyError, "Can't load dependency #{e}")
      end.compact
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
      create_class_commands unless @class_commands.to_s.empty?
      check_for_method_conflicts unless @force
      @namespace ? create_namespace : include_in_universe
    end

    def include_in_universe(lib_module=@module)
      Boson::Universe.send :include, lib_module
      Boson::Universe.send :extend_object, Boson.main_object
    end

    def create_class_commands
      Alias.manager.create_aliases(:any_to_instance_method, @module.to_s=>@class_commands.invert)
    end

    def check_for_method_conflicts
      conflicts = @namespace ? (Boson.main_object.respond_to?(@namespace) ? [@namespace] : []) :
        Util.common_instance_methods(@module, Boson::Universe)
      unless conflicts.empty?
        raise MethodConflictError,"The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def namespace_object
      @namespace_object ||= @namespace ? Boson.invoke(@namespace) : Boson.main_object
    end

    def create_namespace
      if @object_namespace && @module.instance_methods.include?(@namespace)
        include_in_universe
        @namespace_delegate = true
        namespace_object.instance_eval("class<<self;self;end").send(:define_method, :boson_commands) {
          self.class.instance_methods(false) }
      else
        Commands::Namespace.create(@namespace, @module)
        if (lib = Boson.library(Boson::Commands::Namespace, :module))
          lib.commands << @namespace
          lib.create_commands([@namespace])
        end
        Commands::Namespace.add_universe(namespace_object)
      end
      @commands += Boson.invoke(@namespace).boson_commands
    end
  end
end