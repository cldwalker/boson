module Boson
  # A command starts with the functionality of a ruby method and adds benefits with options, render_options, etc.
  class Command
    # Creates a command given its name and a library.
    def self.create(name, library)
      new (library.commands_hash[name] || {}).merge({:name=>name, :lib=>library.name, :namespace=>library.namespace})
    end

    # Finds a command, namespaced or not and aliased or not. If found returns the
    # command object, otherwise returns nil.
    def self.find(command, commands=Boson.commands)
      command, subcommand = command.to_s.split('.', 2)
      is_namespace_command = lambda {|current_command|
        [current_command.name, current_command.alias].include?(subcommand) &&
        current_command.library && (current_command.library.namespace == command)
      }
      find_lambda = subcommand ? is_namespace_command : lambda {|e| [e.name, e.alias].include?(command)}
      commands.find(&find_lambda)
    end

    ATTRIBUTES = [:name, :lib, :alias, :description, :options, :args]
    attr_accessor *(ATTRIBUTES + [:render_options, :namespace, :default_option])
    # A hash of attributes which map to instance variables and values. :name
    # and :lib are required keys.
    #
    # Attributes that can be configured:
    # * *:description*: Description that shows up in command listings
    # * *:alias*: Alternative name for command
    # * *:options*: Hash of options passed to OptionParser
    # * *:render_options*: Hash of rendering options passed to OptionParser
    # * *:global_options*: Boolean to enable using global options without having to define render_options or options.
    # * *:args*: Should only be set if not automatically set. This attribute is only
    #   important for commands that have options/render_options. Its value can be an array
    #   (as ArgumentInspector.scrape_with_eval produces), a number representing
    #   the number of arguments or '*' if the command has a variable number of arguments.
    # * *:default_option* Only for an option command that has one or zero arguments. This treats the given
    #   option as an optional first argument. Example:
    #     # For a command with default option 'query' and options --query and -v
    #     'some -v'   -> '--query=some -v'
    #     '-v'        -> '-v'
    def initialize(hash)
      @name = hash[:name] or raise ArgumentError
      @lib = hash[:lib] or raise ArgumentError
      [:alias, :description, :render_options, :options, :namespace, :default_option,
        :global_options].each do |e|
          instance_variable_set("@#{e}", hash[e]) if hash[e]
      end
      if hash[:args]
        if hash[:args].is_a?(Array)
          @args = hash[:args]
        elsif hash[:args].to_s[/^\d+/]
          @arg_size = hash[:args].to_i
        elsif hash[:args] == '*'
          @args = [['*args']]
        end
      end
    end

    # Library object a command belongs to.
    def library
      @library ||= Boson.library(@lib)
    end

    # Array of array args with optional defaults. Scraped with ArgumentInspector.
    def args(lib=library)
      @args ||= begin
        if lib && File.exists?(lib.library_file || '')
          @file_parsed_args = true
          file_string = Boson::FileLibrary.read_library_file(lib.library_file)
          ArgumentInspector.scrape_with_text(file_string, @name)
        end
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

    # Usage string for command, created from options and args.
    def usage
      return '' if options.nil? && args.nil?
      usage_args = args && @options && !has_splat_args? ?
        (@default_option ? [[@default_option.to_s, @file_parsed_args ? ''.inspect : '']] + args[0..-2] :
        args[0..-2]) : args
      str = args ? usage_args.map {|e|
        (e.size < 2) ? "[#{e[0]}]" : "[#{e[0]}=#{@file_parsed_args ? e[1] : e[1].inspect}]"
      }.join(' ') : '[*unknown]'
      str + option_help
    end

    # Full name is only different than name if a command has a namespace.
    # The full name should be what you would type to execute the command.
    def full_name
      @namespace ? "#{@namespace}.#{@name}" : @name
    end

    #:stopdoc:
    def has_splat_args?
      @args && @args.any? {|e| e[0][/^\*/] }
    end

    def option_command?
      options || render_options || @global_options
    end

    def arg_size
      @arg_size = args ? args.size : nil unless instance_variable_defined?("@arg_size")
      @arg_size
    end

    def file_parsed_args?
      @file_parsed_args
    end

    def marshal_dump
      if @args && @args.any? {|e| e[1].is_a?(Module) }
        @args.map! {|e| e.size == 2 ? [e[0], e[1].inspect] : e }
        @file_parsed_args = true
      end
      [@name, @alias, @lib, @description, @options, @render_options, @args, @default_option]
    end

    def marshal_load(ary)
      @name, @alias, @lib, @description, @options, @render_options, @args, @default_option = ary
    end
    #:startdoc:
  end
end