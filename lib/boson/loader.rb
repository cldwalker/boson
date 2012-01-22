module Boson
  # Raised if a library has a method which conflicts with existing methods in Boson.main_object.
  class MethodConflictError < LoaderError; end

  # This module is mixed into Library to give it load() functionality.
  # When creating your own Library subclass, you should override load_source_and_set_module
  # You can override other methods in this module as needed.
  #
  # === Module Callbacks
  # For libraries that have a module i.e. RunnerLibrary, the following class methods
  # are invoked in the order below when loading a library:
  #
  # [*:config*] This method returns a library's hash of attributes as explained by Library.new. This is useful
  #             for distributing libraries with a default configuration. The library attributes specified here
  #             are overridden by ones a user has in their config file except for the :commands attribute, which
  #             is recursively merged together.
  # [*:append_features*] In addition to its normal behavior, this method's return value determines if a
  #                      library is loaded in the current environment. This is useful for libraries that you
  #                      want loaded by default but not in some environments i.e. different ruby versions or
  #                      in irb but not in script/console. Remember to use super when returning true.
  # [*:included*] In addition to its normal behavior, this method should be used to require external libraries.
  #               Although requiring dependencies could be done anywhere in a module, putting dependencies here
  #               are encouraged. By not having dependencies hardcoded in a module, it's possible to analyze
  #               and view a library's commands without having to install and load its dependencies.
  #               If creating commands here, note that conflicts with existing commands won't be detected.
  # [*:after_included*] This method is called after included() to initialize functionality. This is useful for
  #                     libraries that are primarily executing ruby code i.e. defining ruby extensions or
  #                     setting irb features. This method isn't called when indexing a library.
  module Loader
    # Loads a library and its dependencies and returns true if library loads correctly.
    def load
      @gems ||= []
      load_source_and_set_module
      module_callbacks if @module
      yield if block_given?
      detect_additions { load_module_commands } if (@module || @class_commands)
      before_library_commands
      set_library_commands
      after_library_commands
      loaded_correctly? && (@loaded = true)
    end

    # Load the source and set instance variables necessary to make a library valid i.e. @module.
    def load_source_and_set_module; end

    def before_library_commands; end

    def after_library_commands; end

    # Boolean which indicates if library loaded correctly.
    def loaded_correctly?
      !!@module
    end

    #:stopdoc:
    def module_callbacks
      set_config(@module.config) if @module.respond_to?(:config)
      if @module.respond_to?(:append_features)
        raise AppendFeaturesFalseError unless @module.append_features(Module.new)
      end
    end

    def load_module_commands
      initialize_library_module
    rescue MethodConflictError => err
      handle_method_conflict_error err
    end

    def handle_method_conflict_error(err)
      raise MethodConflictError, err.message
    end

    def detect_additions(options={}, &block)
      options[:object_methods] = @object_methods if !@object_methods.nil?
      detected = Util.detect(options, &block)
      @gems += detected[:gems] if detected[:gems]
      @commands += detected[:methods].map {|e| e.to_s }
      detected
    end

    def initialize_library_module
      @module = @module ? Util.constantize(@module) : Util.create_module(Boson::Commands, clean_name)
      raise(LoaderError, "No module for library #{@name}") unless @module
      if (conflict = Util.top_level_class_conflict(Boson::Commands, @module.to_s))
        warn "Library module '#{@module}' may conflict with top level class/module '#{conflict}' references in"+
          " your libraries. Rename your module to avoid this warning."
      end

      Manager.create_class_aliases(@module, @class_commands) unless @class_commands.nil? ||
        @class_commands.empty? || @method_conflict
      check_for_method_conflicts unless @force
      after_initialize_library_module
    end

    def after_initialize_library_module
      include_in_universe
    end

    def include_in_universe(lib_module=@module)
      Boson::Universe.send :include, lib_module
      @module.after_included if lib_module.respond_to?(:after_included) && !@index
      Boson::Universe.send :extend_object, Boson.main_object
    end

    def check_for_method_conflicts
      conflicts = method_conflicts
      unless conflicts.empty?
        raise MethodConflictError,"The following commands conflict with existing commands: #{conflicts.join(', ')}"
      end
    end

    def method_conflicts
      (@module.instance_methods + @module.private_instance_methods) &
        (Boson.main_object.methods + Boson.main_object.private_methods)
    end

    def set_library_commands
      aliases = @commands_hash.select {|k,v| @commands.include?(k) }.map {|k,v| v[:alias]}.compact
      @commands -= aliases
      clean_library_commands
      @commands.uniq!
    end

    def clean_library_commands
    end
    #:startdoc:
  end
end
