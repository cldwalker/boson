module Boson
  # Raised if a library has methods which conflict with existing methods
  class MethodConflictError < LoaderError; end

  # This module is mixed into Library to give it load() functionality. When
  # creating your own Library subclass, you should at least override
  # load_source_and_set_module.
  module Loader
    # Loads a library and its dependencies and returns true if library loads
    # correctly.
    def load
      load_source_and_set_module
      module_callbacks if @module
      yield if block_given? # load dependencies
      detect_additions { load_commands } if load_commands?
      set_library_commands
      loaded_correctly? && (@loaded = true)
    end

    # Load the source and set instance variables necessary to make a library
    # valid i.e. @module.
    def load_source_and_set_module; end

    # Callbacks for @module before loading
    def module_callbacks; end

    # Determines if load_commands should be called
    def load_commands?
      @module
    end

    # Wraps around module loading for unexpected additions
    def detect_additions(options={}, &block)
      Util.detect(options, &block).tap do |detected|
        @commands.concat detected[:methods].map(&:to_s)
      end
    end

    def load_commands
      @module = @module ? Util.constantize(@module) :
        Util.create_module(Boson::Commands, clean_name)
      before_load_commands
      check_for_method_conflicts unless @force
      actual_load_commands
    rescue MethodConflictError => err
      handle_method_conflict_error err
    end

    # Boolean which indicates if library loaded correctly.
    def loaded_correctly?
      !!@module
    end

    # Callback for @module after it's been included
    def after_include; end

    def handle_method_conflict_error(err)
      raise MethodConflictError, err.message
    end

    # Called after @module has been created
    def before_load_commands; end

    # Actually includes module and its commands
    def actual_load_commands
      include_in_universe
    end

    # Returns array of method conflicts
    def method_conflicts
      (@module.instance_methods + @module.private_instance_methods) &
        (Boson.main_object.methods + Boson.main_object.private_methods)
    end

    # Handles setting and cleaning @commands
    def set_library_commands
      clean_library_commands
    end

    # Cleans @commands from set_library_commands
    def clean_library_commands
      aliases = @commands_hash.select {|k,v| @commands.include?(k) }.
        map {|k,v| v[:alias] }.compact
      @commands -= aliases
      @commands.uniq!
    end

    private
    def include_in_universe(lib_module=@module)
      Boson::Universe.send :include, lib_module
      after_include
      Boson::Universe.send :extend_object, Boson.main_object
    end

    def check_for_method_conflicts
      conflicts = method_conflicts
      unless conflicts.empty?
        raise MethodConflictError, "The following commands conflict with " +
          "existing commands: #{conflicts.join(', ')}"
      end
    end
  end
end
