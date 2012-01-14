module Boson
  # A command starts with the functionality of a ruby method and adds benefits with options, etc.
  class Command
    module API
      # Creates a command given its name and a library.
      def create(name, library)
        new(new_attributes(name, library))
      end
    end

    class <<self; include API; end

    # Used to generate a command's initial attributes when creating a command object
    def self.new_attributes(name, library)
      (library.commands_hash[name] || {}).merge({:name=>name, :lib=>library.name, :namespace=>library.namespace})
    end

    # Finds a command, namespaced or not and aliased or not. If found returns the
    # command object, otherwise returns nil.
    def self.find(command, commands=Boson.commands)
      if command.to_s.include?(NAMESPACE)
        command, subcommand = command.to_s.split(NAMESPACE, 2)
        commands.find {|current_command|
          [current_command.name, current_command.alias].include?(subcommand) &&
          current_command.library && (current_command.library.namespace == command)
        }
      else
        commands.find {|e| [e.name, e.alias].include?(command) && !e.namespace}
      end
    end

    # One line usage for a command if it exists
    def self.usage(command)
      (cmd = find(command)) ? "#{command} #{cmd.usage}" : "Command '#{command}' not found"
    end

    ATTRIBUTES = [:name, :lib, :alias, :desc, :options, :args, :config]
    attr_accessor *(ATTRIBUTES + [:namespace, :default_option])
    INIT_ATTRIBUTES = [:alias, :desc, :options, :namespace, :default_option,
      :option_command ]
    # A hash of attributes which map to instance variables and values. :name
    # and :lib are required keys.
    #
    # Attributes that can be configured:
    # [*:desc*] Description that shows up in command listings
    # [*:alias*] Alternative name for command
    # [*:options*] Hash of options passed to OptionParser
    # [*:args*] Should only be set if not automatically set. This attribute is only
    #           important for commands that have options. Its value can be an array
    #           (as ArgumentInspector.scrape_with_eval produces), a number representing
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
      def after_initialize(hash)
      end
    end
    include API

    # Library object a command belongs to.
    def library
      @library ||= Boson.library(@lib)
    end

    # Array of array args with optional defaults. Scraped with ArgumentInspector.
    def args(lib=library)
      @args = !@args.nil? ? @args : begin
        if lib
          file_string, meth = file_string_and_method_for_args(lib)
          (file_string && meth && (@file_parsed_args = true) &&
            ArgumentInspector.scrape_with_text(file_string, meth))
        end || false
      end
    end

    # Option parser for command as defined by @options.
    def option_parser
      @option_parser ||= OptionParser.new(@options || {})
    end

    # Help string for options if a command has it.
    def option_help
      @options ? option_parser.to_s : ''
    end

    def option_command?
      options || @option_command
    end

    def basic_usage
      return '' if options.nil? && args.nil?
      usage_args = args && @options && !has_splat_args? ?
        (@default_option ? [[@default_option.to_s, @file_parsed_args ? ''.inspect : '']] + args[0..-2] :
        args[0..-2]) : args
      args ? usage_args.map {|e|
        (e.size < 2) ? "[#{e[0]}]" : "[#{e[0]}=#{@file_parsed_args ? e[1] : e[1].inspect}]"
      }.join(' ') : '[*unknown]'
    end

    # Usage string for command, created from options and args.
    def usage
      basic_usage + option_help
    end

    # Full name is only different than name if a command has a namespace.
    # The full name should be what you would type to execute the command.
    def full_name
      @namespace ? "#{@namespace}.#{@name}" : @name
    end

    #:stopdoc:
    # until @config is consistent in index + actual loading
    def config
      @config ||= {}
    end

    def file_string_and_method_for_args(lib)
      if !lib.is_a?(ModuleLibrary) && (klass_method = (lib.class_commands || {})[@name])
        klass, meth = klass_method.split(NAMESPACE, 2)
        if (meth_locations = MethodInspector.find_class_method_locations(klass, meth))
          file_string = File.read meth_locations[0]
        end
      elsif File.exists?(lib.library_file || '')
        file_string, meth = FileLibrary.read_library_file(lib.library_file), @name
      end
      [file_string, meth]
    end

    def has_splat_args?
      !!(args && @args[-1] && @args[-1][0][/^\*/])
    end

    def arg_size
      @arg_size = args ? args.size : nil unless instance_variable_defined?("@arg_size")
      @arg_size
    end

    def file_parsed_args?
      @file_parsed_args
    end

    # Deprecated method
    def description
      puts "@command.description has been changed to @command.desc. Delete your old " +
        "Boson index at ~/.boson/command/index.marshal for Boson to work from the commandline." +
        "This will be removed in boson 0.5"
      Kernel.exit
    end

    def marshal_dump
      if @args && @args.any? {|e| e[1].is_a?(Module) }
        @args.map! {|e| e.size == 2 ? [e[0], e[1].inspect] : e }
        @file_parsed_args = true
      end
      [@name, @alias, @lib, @desc, @options, @render_options, @args, @default_option]
    end

    def marshal_load(ary)
      @name, @alias, @lib, @desc, @options, @render_options, @args, @default_option = ary
    end
    #:startdoc:
  end
end
