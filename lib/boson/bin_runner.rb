module Boson
  # This class handles the boson executable (boson command execution from the commandline). Any changes
  # to your commands are immediately available from the commandline except for changes to the main config file.
  # For those changes to take effect you need to explicitly load and index the libraries with --index.
  # See RepoIndex to understand how Boson can immediately detect the latest commands.
  #
  # Usage for the boson shell command looks like this:
  #   boson [GLOBAL OPTIONS] [COMMAND] [ARGS] [COMMAND OPTIONS]
  #
  # The boson executable comes with these global options:
  # [:help]  Gives a basic help of global options. When a command is given the help shifts to a command's help.
  # [:execute] Like ruby -e, this executes a string of ruby code. However, this has the advantage that all
  #            commands are available as normal methods, automatically loading as needed. This is a good
  #            way to call commands that take non-string arguments.
  class BinRunner < Runner
    GLOBAL_OPTIONS =  {
      :version=>{:type=>:boolean, :desc=>"Prints the current version"},
      :execute=>{:type=>:string, :desc=>"Executes given arguments as a one line script"},
      :help=>{:type=>:boolean, :desc=>"Displays this help message or a command's help if given a command"},
      :ruby_debug=>{:type=>:boolean, :desc=>"Sets $DEBUG", :alias=>'D'},
      :debug=>{:type=>:boolean, :desc=>"Prints debug info for boson"},
      :load_path=>{:type=>:string, :desc=>"Add to front of $LOAD_PATH", :alias=>'I'}
    } #:nodoc:

    module API
      attr_accessor :command

      # Starts, processes and ends a commandline request.
      def start(args=ARGV)
        super
        @command, @options, @args = parse_args(args)

        $:.unshift(*options[:load_path].split(":")) if options[:load_path]
        Runner.debug = true if options[:debug]
        $DEBUG = true if options[:ruby_debug]
        return if early_option?(args)

        init

        if @options[:help]
          autoload_command @command
          Boson.invoke(:usage, @command, verbose: verbose)
        elsif @options[:execute]
          define_autoloader
          Boson.main_object.instance_eval @options[:execute]
        else
          execute_command(@command, @args)
        end
      rescue NoMethodError
        abort_with no_method_error_message
      rescue
        abort_with default_error_message
      end

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

      def verbose
        false
      end

      def no_method_error_message #:nodoc:
        @command = @command.to_s
        if $!.backtrace.grep(/`(invoke|full_invoke)'$/).empty? ||
          !$!.message[/undefined method `(\w+\.)?#{@command.split(NAMESPACE)[-1]}'/]
            default_error_message
        else
          @command.to_s[/\w+/] &&
            (!(Index.read && Index.find_command(@command[/\w+/])) || @command.include?(NAMESPACE)) ?
            "Error: Command '#{@command}' not found" : default_error_message
        end
      end

      # Loads libraries and handles non-critical options
      def init
        Runner.in_shell = true
        super
      end

      # Hash of global options passed in from commandline
      def options
        @options ||= {}
      end

      #:stopdoc:
      def abort_with(message)
        abort message
      end

      def default_error_message
        "Error: #{$!.message}"
      end

      def autoload_command(cmd)
        if !Boson.can_invoke?(cmd, false)
          update_index
          super(cmd, load_options)
        end
      end

      def update_index
        Index.update(verbose: verbose)
      end

      def default_libraries
        super + Boson.repos.map {|e| e.config[:bin_defaults] || [] }.flatten +
          Dir.glob('Bosonfile')
      end

      def execute_command(cmd, args)
        @command = cmd # for external errors
        autoload_command cmd
        Boson.full_invoke(cmd, args)
      rescue ArgumentError
        if allowed_argument_error?($!, cmd, args)
          abort_with "'#{cmd}' was called incorrectly.\n" + Command.usage(cmd)
        else
          raise
        end
      end

      def allowed_argument_error?(err, cmd, args)
        (err.message[/wrong number of arguments/] &&
          (cmd_obj = Command.find(cmd)) && cmd_obj.arg_size != args.size)
      end

      def parse_args(args)
        @option_parser = OptionParser.new(GLOBAL_OPTIONS)
        options = @option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = @option_parser.non_opts
        [new_args[0], options, new_args[1..-1]]
      end

      def print_usage_header
        puts "boson [GLOBAL OPTIONS] [COMMAND] [ARGS] [COMMAND OPTIONS]\n\n"
      end

      def print_usage
        print_usage_header
        @option_parser.print_usage_table
      end
      #:startdoc:
    end

    class << self
      include API
    end
  end
end
