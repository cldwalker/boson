module Boson
  # This class handles the boson executable.
  #
  # Usage for the boson shell command looks like this:
  #   boson [GLOBAL OPTIONS] [COMMAND] [ARGS] [COMMAND OPTIONS]
  #
  # The boson executable comes with several global options: :version, :execute,
  # :ruby_debug, :debug, and :load_path.
  class BinRunner < BareRunner
    GLOBAL_OPTIONS.update(
      version: {type: :boolean, desc: "Prints the current version"},
      execute: {type: :string,
        desc: "Executes given arguments as a one line script"},
      ruby_debug: {type: :boolean, desc: "Sets $DEBUG", alias: 'D'},
      debug: {type: :boolean, desc: "Prints debug info for boson"},
      load_path: {type: :string, desc: "Add to front of $LOAD_PATH", alias: 'I'}
    )

    module API
      attr_accessor :command

      # Executes functionality from either an option or a command
      def execute_option_or_command(options, command, args)
        options[:execute] ? eval_execute_option(options[:execute]) :
          execute_command(command, args)
      end

      # Evaluates :execute option.
      def eval_execute_option(str)
        Boson.main_object.instance_eval str
      end

      # Returns true if an option does something and exits early
      def early_option?(args)
        if @options[:version]
          puts("boson #{Boson::VERSION}")
          true
        elsif args.empty? || (@command.nil? && !@options[:execute])
          print_usage
          true
        else
          false
        end
      end

      # Determines verbosity of this class
      def verbose
        false
      end

      # Handles no method errors
      def no_method_error_message(err)
        @command = @command.to_s
        if err.backtrace.grep(/`(invoke|full_invoke)'$/).empty? ||
          !err.message[/undefined method `(\w+\.)?#{command_name(@command)}'/]
            default_error_message($!)
        else
          command_not_found?(@command) ?
            "Error: Command '#{@command}' not found" : default_error_message(err)
        end
      end

      # Determine command name given full command name. Overridden by namespaces
      def command_name(cmd)
        cmd
      end

      # Determines if a NoMethodError is a command not found error
      def command_not_found?(cmd)
        cmd[/\w+/]
      end

      # Constructs error message
      def default_error_message(err)
        "Error: #{err.message}"
      end

      def print_usage_header
        puts "boson [GLOBAL OPTIONS] [COMMAND] [ARGS] [COMMAND OPTIONS]\n\n"
      end

      # prints full usage
      def print_usage
        print_usage_header
        @option_parser.print_usage_table
      end
    end
    extend API

    # Starts, processes and ends a commandline request.
    def self.start(args=ARGV)
      super
      @command, @options, @args = parse_args(args)

      $:.unshift(*options[:load_path].split(":")) if options[:load_path]
      Boson.debug = true if options[:debug]
      $DEBUG = true if options[:ruby_debug]
      return if early_option?(args)
      Boson.in_shell = true

      init
      execute_option_or_command(@options, @command, @args)
    rescue NoMethodError
      abort_with no_method_error_message($!)
    rescue
      abort_with default_error_message($!)
    end

    # Hash of global options passed in from commandline
    def self.options
      @options ||= {}
    end
  end
end
