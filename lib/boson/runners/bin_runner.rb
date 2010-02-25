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
  # [:verbose] Using this along with :help option shows more help. Also gives verbosity to other actions i.e. loading.
  # [:execute] Like ruby -e, this executes a string of ruby code. However, this has the advantage that all
  #            commands are available as normal methods, automatically loading as needed. This is a good
  #            way to call commands that take non-string arguments.
  # [:console] This drops Boson into irb after having loaded default commands and any explict libraries with
  #            :load option. This is a good way to start irb with only certain libraries loaded.
  # [:load] Explicitly loads a list of libraries separated by commas. Most useful when used with :console option.
  #         Can also be used to explicitly load libraries that aren't being detected automatically.
  # [:index] Updates index for given libraries allowing you to use them. This is useful if Boson's autodetection of
  #          changed libraries isn't picking up your changes. Since this option has a :bool_default attribute, arguments
  #          passed to this option need to be passed with '=' i.e. '--index=my_lib'.
  # [:render] Toggles the auto-rendering done for commands that don't have views. Doesn't affect commands that already have views.
  #           Default is false. Also see Auto Rendering section below.
  # [:pager_toggle] Toggles Hirb's pager in case you'd like to pipe to another command.
  #
  # ==== Auto Rendering
  # Commands that don't have views (defined via render_options) have their return value auto-rendered as a view as follows:
  # * nil,false and true aren't rendered
  # * arrays are rendered with Hirb's tables
  # * non-arrays are printed with inspect()
  # * Any of these cases can be toggled to render/not render with the global option :render
  # To turn off auto-rendering by default, add a :no_auto_render: true entry to the main config.
  class BinRunner < Runner
    GLOBAL_OPTIONS =  {
      :verbose=>{:type=>:boolean, :desc=>"Verbose description of loading libraries, errors or help"},
      :version=>{:type=>:boolean, :desc=>"Prints the current version"},
      :index=>{:type=>:array, :desc=>"Libraries to index. Libraries must be passed with '='.",
        :bool_default=>nil, :values=>all_libraries, :regexp=>true, :enum=>false},
      :execute=>{:type=>:string, :desc=>"Executes given arguments as a one line script"},
      :console=>{:type=>:boolean, :desc=>"Drops into irb with default and explicit libraries loaded"},
      :help=>{:type=>:boolean, :desc=>"Displays this help message or a command's help if given a command"},
      :load=>{:type=>:array, :values=>all_libraries, :regexp=>true, :enum=>false,
        :desc=>"A comma delimited array of libraries to load"},
      :unload=>{:type=>:string, :desc=>"Acts as a regular expression to unload default libraries"},
      :render=>{:type=>:boolean, :desc=>"Renders a Hirb view from result of command without options"},
      :pager_toggle=>{:type=>:boolean, :desc=>"Toggles Hirb's pager"},
      :option_commands=>{:type=>:boolean, :desc=>"Toggles on all commands to be defined as option commands" }
    } #:nodoc:

    PIPE = '+'

    class <<self
      attr_accessor :command

      # Starts, processes and ends a commandline request.
      def start(args=ARGV)
        @command, @options, @args = parse_args(args)
        return puts(Boson::VERSION) if @options[:version]
        return print_usage if args.empty? || (@command.nil? && !@options[:console] && !@options[:execute])
        return ConsoleRunner.bin_start(@options[:console], @options[:load]) if @options[:console]
        init

        if @options[:help]
          autoload_command @command
          Boson.invoke(:usage, @command, :verbose=>@options[:verbose])
        elsif @options[:execute]
          define_autoloader
          Boson.main_object.instance_eval @options[:execute]
        else
          execute_command
        end
      rescue
        is_invalid_command = lambda {|command|
          !(Index.read && Index.find_command(command[/\w+/])) ||
          (command.include?('.') && $!.is_a?(NoMethodError)) }
        print_error_message @command.to_s[/\w+/] && is_invalid_command.call(@command) ?
          "Error: Command '#{@command}' not found" : "Error: #{$!.message}"
      end

      # Loads libraries and handles non-critical options
      def init
        Runner.in_shell = true
        Command.all_option_commands = true if @options[:option_commands]
        super

        if @options.key?(:index)
          Index.update(:verbose=>true, :libraries=>@options[:index])
          @index_updated = true
        elsif !@options[:help] && @command && Boson.can_invoke?(@command)
          Index.update(:verbose=>@options[:verbose])
          @index_updated = true
        end
        Manager.load @options[:load], load_options if @options[:load]
        View.toggle_pager if @options[:pager_toggle]
      end

      # Hash of global options passed in from commandline
      def options
        @options ||= {}
      end

      # Commands to executed, in order given by user
      def commands
        @all_args.map {|e| e[0]}
      end
      #:stopdoc:
      def print_error_message(message)
        message += "\nOriginal error: #{$!}\n" + $!.backtrace.slice(0,10).map {|e| "  " + e }.join("\n") if options[:verbose]
        $stderr.puts message
      end

      def autoload_command(cmd)
        if !Boson.can_invoke?(cmd, false)
          unless @index_updated
            Index.update(:verbose=>@options[:verbose])
            @index_updated = true
          end
          super(cmd, load_options)
        end
      end

      def default_libraries
        libs = super + Boson.repos.map {|e| e.config[:bin_defaults] || [] }.flatten + Dir.glob('Bosonfile')
        @options[:unload] ?  libs.select {|e| e !~ /#{@options[:unload]}/} : libs
      end

      def execute_command
        output = @all_args.inject(nil) {|acc, (command,*args)|
          begin
            @command = command # for external errors
            autoload_command command
            args = translate_args(args, acc)
            Boson.full_invoke(command, args)
          rescue ArgumentError
            if $!.class == OptionCommand::CommandArgumentError || ($!.message[/wrong number of arguments/] &&
              (cmd = Command.find(command)) && cmd.arg_size != args.size)
              print_error_message "'#{command}' was called incorrectly."
              Boson.invoke(:usage, command, :one_line=>true)
              return
            else
              raise
            end
          end
        }
        render_output output
      end

      def translate_args(args, piped)
        args.unshift piped if piped
        args
      end

      def parse_args(args)
        @all_args = Util.split_array_by(args, PIPE)
        args = @all_args[0]
        @option_parser = OptionParser.new(GLOBAL_OPTIONS)
        options = @option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = @option_parser.non_opts
        @all_args[0] = new_args
        [new_args[0], options, new_args[1..-1]]
      end

      def render_output(output)
        if (!Scientist.rendered && !View.silent_object?(output)) ^ @options[:render] ^
          Boson.repo.config[:no_auto_render]
            opts = output.is_a?(String) ? {:method=>'puts'} :
              {:inspect=>!output.is_a?(Array) || (Scientist.global_options || {})[:render] }
            View.render output, opts
        end
      end

      def print_usage
        puts "boson [GLOBAL OPTIONS] [COMMAND] [ARGS] [COMMAND OPTIONS]\n\n"
        puts "GLOBAL OPTIONS"
        View.enable
        @option_parser.print_usage_table
        if @options[:verbose]
          Manager.load [Boson::Commands::Core]
          puts "\n\nDEFAULT COMMANDS"
          Boson.invoke :commands, :fields=>["name", "usage", "description"], :description=>false
        end
      end
      #:startdoc:
    end
  end
end