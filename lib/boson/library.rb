module Boson
  # A library is a group of commands (Command objects) usually grouped together
  # by a module.  Libraries are loaded from different sources depending on the
  # library subclass.
  #
  # == Naming a Library Module
  # Although you can name a library module almost anything, here's the fine print:
  # * A module can have any name if it's the only module in a library.
  # * If there are multiple modules in a file library, the module's name must be a camelized version
  #   of the file's basename i.e. ~/.boson/commands/ruby_core.rb -> RubyCore.
  # * Although modules are evaluated under the Boson::Commands namespace, Boson will warn you about creating
  #   modules whose name is the same as a top level class/module. The warning is to encourage users to stay
  #   away from error-prone libraries. Once you introduce such a module, _all_ libraries assume the nested module
  #   over the top level module and the top level module has to be prefixed with '::' _everywhere_.
  #
  # == Configuration
  # Libraries and their commands can be configured in different ways in this order:
  # * If library is a FileLibrary, commands be configured with a config method attribute (see Inspector).
  # * If a library has a module, you can set library + command attributes via the config() callback (see Loader).
  #
  # === Creating Your Own Library
  # To create your own subclass you need to define what sources the subclass can
  # handle with handles(). See Loader to see what instance methods to override
  # for a subclass.
  class Library
    include Loader
    class <<self
      attr_accessor :handle_blocks
      # Returns true when the subclass is chosen to load.
      def handles(&block)
        (Library.handle_blocks ||= []) << [self,block]
      end
    end

    # Public attributes for use outside of Boson.
    ATTRIBUTES = [:commands, :loaded, :module, :name]
    attr_reader *(ATTRIBUTES + [:commands_hash, :library_file])
    # Private attribute for use within Boson.
    attr_reader :new_module, :new_commands, :lib_file

    # Creates a library object with a hash of attributes which must include a
    # :name attribute.  Each hash pair maps directly to an instance variable and
    # value. Defaults for attributes are read from
    # config[:libraries][@library_name][@attribute].
    #
    # Attributes that can be configured:
    # [*:commands*] A hash or array of commands that belong to this library. A hash configures command attributes
    #               for the given commands with command names pointing to their configs. See Command.new for a
    #               command's configurable attributes. If an array, the commands are set for the given library,
    #               overidding default command detection. Example:
    #                :commands=>{'commands'=>{:desc=>'Lists commands', :alias=>'com'}}
    # [*:force*] Boolean which forces a library to ignore when a library's methods are overriding existing ones.
    #            Use with caution. Default is false.
    # [*:object_methods*] Boolean which detects any Object/Kernel methods created when loading a library and automatically
    #                     adds them to a library's commands. Default is true.
    def initialize(hash)
      before_initialize
      @name = set_name(hash.delete(:name)) or
        raise ArgumentError, "Library missing required key :name"
      @loaded = false
      @commands_hash = {}
      @commands = []
      set_config (config[:libraries][@name] || {}).merge(hash), true
      set_command_aliases(config[:command_aliases])
    end

    # A concise symbol version of a library type i.e. FileLibrary -> :file.
    def library_type
      str = self.class.to_s[/::(\w+)Library$/, 1] || 'library'
      str.downcase.to_sym
    end

    # handles names under directories
    def clean_name
      @name[/\w+$/]
    end

    # sets name
    def set_name(name)
      name.to_s
    end

    module API
      # The object a library uses for executing its commands.
      def namespace_object
        @namespace_object ||= Boson.main_object
      end

      def before_initialize
      end

      def local?
        false
      end

      def config
        Boson.config
      end
    end
    include API

    # Command objects of library's commands
    def command_objects(names=self.commands, command_array=Boson.commands)
      command_array.select {|e| names.include?(e.name) && e.lib == self.name }
    end

    # Command object for given command name
    def command_object(name)
      command_objects([name])[0]
    end

    private
    def set_attributes(hash, force=false)
      hash.each do |k,v|
        if instance_variable_get("@#{k}").nil? || force
          instance_variable_set("@#{k}", v)
        end
      end
    end

    def set_config(config, force=false)
      if (commands = config.delete(:commands))
        if commands.is_a?(Array)
          @commands += commands
          @pre_defined_commands = true
        elsif commands.is_a?(Hash)
          @commands += commands.keys
          @commands_hash = Util.recursive_hash_merge commands, @commands_hash
        end
      end
      set_command_aliases config.delete(:command_aliases) if config[:command_aliases]
      set_attributes config, force
    end

    def set_command_aliases(command_aliases)
      (command_aliases || {}).each do |cmd, cmd_alias|
        @commands_hash[cmd] ||= {}
        @commands_hash[cmd][:alias] ||= cmd_alias
      end
    end
  end
end
