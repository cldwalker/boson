module Boson
  # A command starts with the functionality of a ruby method and adds benefits
  # with options, etc.
  class Command
    module API
      # Creates a command given its name and a library.
      def create(name, library)
        new(new_attributes(name, library))
      end

      # Attributes passed to commands from its library
      def library_attributes(library)
        {lib: library.name}
      end

      # Finds a command, aliased or not. If found returns the command object,
      # otherwise returns nil.
      def find(command, commands=Boson.commands)
        command && commands.find {|e| [e.name, e.alias].include?(command) }
      end
    end
    extend API

    # Generates a command's initial attributes when creating a command object
    def self.new_attributes(name, library)
      (library.commands_hash[name] || {}).merge(name: name).
        update(library_attributes(library))
    end

    # One line usage for a command if it exists
    def self.usage(command)
      (cmd = find(command)) ? "#{command} #{cmd.usage}" :
        "Command '#{command}' not found"
    end

    # Attributes that are defined as accessors
    ATTRIBUTES = [:name, :lib, :alias, :desc, :options, :args, :config]
    attr_accessor *(ATTRIBUTES + [:default_option])
    # Attributes that can be passed in at initialization
    INIT_ATTRIBUTES = [:alias, :desc, :options, :default_option, :option_command]
    attr_reader :file_parsed_args

    # Takes a hash of attributes which map to instance variables and values.
    # :name and :lib are required keys.
    #
    # Attributes that can be configured:
    # [*:desc*] Description that shows up in command listings
    # [*:alias*] Alternative name for command
    # [*:options*] Hash of options passed to OptionParser
    # [*:args*] Should only be set if not automatically set. This attribute is only
    #           important for commands that have options. Its value can be an array
    #           , a number representing
    #           the number of arguments or '*' if the command has a variable number of arguments.
    # [*:default_option*] Only for an option command that has one or zero arguments. This treats the given
    #                     option as an optional first argument. Example:
    #                       # For a command with default option 'query' and options --query and -v
    #                       'some -v'   -> '--query=some -v'
    #                       '-v'        -> '-v'
    # [*:config*] A hash for third party libraries to get and set custom command attributes.
    # [*:option_command*] Boolean to wrap a command with an OptionCommand object i.e. allow commands to have options.
    def initialize(attributes)
      hash = attributes.dup
      @name = hash.delete(:name) or raise ArgumentError
      @lib = hash.delete(:lib) or raise ArgumentError
      # since MethodInspector scrapes arguments from file by default
      @file_parsed_args = true
      INIT_ATTRIBUTES.each do |e|
        instance_variable_set("@#{e}", hash.delete(e)) if hash.key?(e)
      end

      after_initialize(hash)

      if (args = hash.delete(:args))
        if args.is_a?(Array)
          @args = args
        elsif args.to_s[/^\d+/]
          @arg_size = args.to_i
        elsif args == '*'
          @args = [['*args']]
        end
      end
      @config = Util.recursive_hash_merge hash, hash.delete(:config) || {}
    end

    module API
      # Called after initialize
      def after_initialize(hash)
      end

      # Alias for a name but plugins may use it to give a more descriptive name
      def full_name
        name
      end
    end
    include API

    # Library object a command belongs to.
    def library
      @library ||= Boson.library(@lib)
    end

    def args(lib=library)
      @args
    end

    # Option parser for command as defined by @options.
    def option_parser
      @option_parser ||= OptionParser.new(@options || {})
    end

    # Help string for options if a command has it.
    def option_help
      @options ? option_parser.to_s : ''
    end

    # Indicates if an OptionCommand
    def option_command?
      options || @option_command
    end

    # One-line usage of args
    def basic_usage
      return '' if options.nil? && args.nil?
      usage_args = args && @options && !has_splat_args? ?
        (@default_option ?
         [[@default_option.to_s, @file_parsed_args ? ''.inspect : '']] +
         args[0..-2] : args[0..-2])
        : args
      args ? usage_args.map {|e|
        (e.size < 2) ? "[#{e[0]}]" :
          "[#{e[0]}=#{@file_parsed_args ? e[1] : e[1].inspect}]"
      }.join(' ') : '[*unknown]'
    end

    # Usage string for command, created from options and args.
    def usage
      basic_usage + option_help
    end

    # until @config is consistent in index + actual loading
    def config
      @config ||= {}
    end

    # Indicates if any arg has a splat
    def has_splat_args?
      !!(args && @args[-1] && @args[-1][0][/^\*/])
    end

    # Number of arguments
    def arg_size
      unless instance_variable_defined?("@arg_size")
        @arg_size = args ? args.size : nil
      end
      @arg_size
    end
  end
end
