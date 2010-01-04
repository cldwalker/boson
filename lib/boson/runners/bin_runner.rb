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
      :verbose=>{:type=>:boolean, :desc=>"Verbose description of loading libraries or help"},
      :index=>{:type=>:array, :desc=>"Libraries to index. Libraries must be passed with '='.",
        :bool_default=>nil, :values=>all_libraries, :regexp=>true},
      :execute=>{:type=>:string, :desc=>"Executes given arguments as a one line script"},
      :console=>{:type=>:boolean, :desc=>"Drops into irb with default and explicit libraries loaded"},
      :help=>{:type=>:boolean, :desc=>"Displays this help message or a command's help if given a command"},
      :load=>{:type=>:array, :values=>all_libraries, :regexp=>true,
        :desc=>"A comma delimited array of libraries to load"},
      :render=>{:type=>:boolean, :desc=>"Renders a Hirb view from result of command without options"},
      :pager_toggle=>{:type=>:boolean, :desc=>"Toggles Hirb's pager"}
    } #:nodoc:

    class <<self
      attr_accessor :command

      # Starts, processes and ends a commandline request.
      def start(args=ARGV)
        @command, @options, @args = parse_args(args)
        return print_usage if args.empty? || (@command.nil? && !@options[:console] && !@options[:execute])
        return ConsoleRunner.bin_start(@options[:console], @options[:load]) if @options[:console]
        init
        View.toggle_pager if @options[:pager_toggle]

        if @options[:help]
          Boson.invoke(:usage, @command, :verbose=>@options[:verbose])
        elsif @options[:execute]
          Boson.main_object.instance_eval @options[:execute]
        else
          execute_command
        end
      rescue Exception
        is_invalid_command = lambda {|command| !Boson.can_invoke?(command[/\w+/]) ||
          (Boson.can_invoke?(command[/\w+/]) && command.include?('.') && $!.is_a?(NoMethodError)) }
        print_error_message @command && is_invalid_command.call(@command) ?
          "Error: Command '#{@command}' not found" : "Error: #{$!.message}"
      end

      # Loads the given command.
      def init
        super
        Index.update(:verbose=>true, :libraries=>@options[:index]) if @options.key?(:index)
        if @options[:load]
          Manager.load @options[:load], load_options
        elsif @options[:execute]
          define_autoloader
        else
          load_command_by_index
        end
      end

      # Hash of global options passed in from commandline
      def options
        @options ||= {}
      end

      #:stopdoc:
      def print_error_message(message)
        message += "\nOriginal error: #{$!}\n" + $!.backtrace.slice(0,10).map {|e| "  " + e }.join("\n") if options[:verbose]
        $stderr.puts message
      end

      def load_command_by_index
        Index.update(:verbose=>@options[:verbose]) if !@options.key?(:index) && Boson.can_invoke?(@command) && !@options[:help]
        if !Boson.can_invoke?(@command, false) && ((lib = Index.find_library(@command)) ||
          (Index.update(:verbose=>@options[:verbose]) && (lib = Index.find_library(@command))))
          Manager.load lib, load_options
        end
      end

      def default_libraries
        super + Boson.repos.map {|e| e.config[:bin_defaults] || [] }.flatten + Dir.glob('Bosonfile')
      end

      def execute_command
        render_output Boson.full_invoke(@command, @args)
      rescue ArgumentError
        # for the rare case it's raise outside of boson
        raise unless $!.backtrace.first.include?('boson/')
        print_error_message "'#{@command}' was called incorrectly."
        Boson.invoke(:usage, @command)
      end

      def parse_args(args)
        @option_parser = OptionParser.new(GLOBAL_OPTIONS)
        options = @option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = @option_parser.non_opts
        [new_args.shift, options, new_args]
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