module Boson
  # Raised if a library has a method which conflicts with existing methods in Boson.main_object.
  class MethodConflictError < LoaderError; end

  # This module is mixed into Library to give it load() functionality.
  # When creating your own Library subclass, you should override load_source_and_set_module
  # You can override other methods in this module as needed.
  module Loader
    # Loads a library and its dependencies and returns true if library loads correctly.
    def load
      load_source_and_set_module
      module_callbacks if @module
      yield if block_given?
      detect_additions { load_module_commands } if load_module_commands?
      before_library_commands
      set_library_commands
      after_library_commands
      loaded_correctly? && (@loaded = true)
    end

    def load_module_commands?
      @module
    end

    # Load the source and set instance variables necessary to make a library
    # valid i.e. @module.
    def load_source_and_set_module; end

    # Callbacks for @module before loading
    def module_callbacks; end

    def before_library_commands; end

    def after_library_commands; end

    # Boolean which indicates if library loaded correctly.
    def loaded_correctly?
      !!@module
    end

    # Callback for @module after it's been included
    def after_include
    end

    #:stopdoc:

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
      @commands += detected[:methods].map {|e| e.to_s }
      detected
    end

    def initialize_library_module
      @module = @module ? Util.constantize(@module) :
        Util.create_module(Boson::Commands, clean_name)
      raise(LoaderError, "No module for library #{@name}") unless @module
      during_initialize_library_module
      check_for_method_conflicts unless @force
      after_initialize_library_module
    end

    def during_initialize_library_module
    end

    def after_initialize_library_module
      include_in_universe
    end

    def include_in_universe(lib_module=@module)
      Boson::Universe.send :include, lib_module
      after_include
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
