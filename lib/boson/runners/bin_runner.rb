module Boson
  # Runs Boson from the commandline. Usage for the boson shell command looks like this:
  #   boson [GLOBAL OPTIONS] [COMMAND] [ARGS] [COMMAND OPTIONS]
  #
  # The boson executable comes with these global options:
  # [:help]  Gives a basic help of global options. When a command is given the help shifts to a command's help.
  # [:verbose] Using this along with :help option shows more help. Also gives verbosity to other actions i.e. loading.
  # [:index] Updates index. This should be called in the unusual case that Boson doesn't detect new commands
  #          and libraries.
  # [:execute] Like ruby -e, this executes a string of ruby code. However, this has the advantage that all
  #            commands are available as normal methods, automatically loading as needed. This is a good
  #            way to call commands that take non-string arguments.
  # [:interactive] This drops Boson into irb after having loaded default commands and any explict libraries with
  #                :load option. This is a good way to start irb with only certain libraries loaded.
  # [:load] Explicitly loads a list of libraries separated by commas. Most useful when used with :interactive option.
  #         Can also be used to explicitly load libraries that aren't being detected automatically.
  class BinRunner < Runner
    GLOBAL_OPTIONS =  {
      :verbose=>{:type=>:boolean, :desc=>"Verbose description of loading libraries or help"},
      [:index, :I]=>{:type=>:boolean, :desc=>"Updates index for libraries and commands"},
      :execute=>{:type=>:string, :desc=>"Executes given arguments as a one line script"},
      :interactive=>{:type=>:boolean, :desc=>"Drops into irb with default and explicit libraries loaded"},
      :help=>{:type=>:boolean, :desc=>"Displays this help message or a command's help if given a command"},
      :load=>{:type=>:array, :values=>all_libraries, :enum=>false, :desc=>"A comma delimited array of libraries to load"}
    } #:nodoc:

    class <<self
      attr_accessor :command
      # Starts, processes and ends a commandline request.
      def start(args=ARGV)
        @command, @options, @args = parse_args(args)
        return print_usage if args.empty? || (@command.nil? && !@options[:interactive] && !@options[:execute])
        return ReplRunner.bin_start(@options[:interactive], @options[:load]) if @options[:interactive]
        init

        if @options[:help]
          print_command_help
        elsif @options[:execute]
          Boson.main_object.instance_eval @options[:execute]
        else
          execute_command
        end
      rescue Exception
        message = (@command && !Boson.can_invoke?(@command[/\w+/])) ?
          "Error: Command '#{@command}' not found" : "Error: #{$!.message}"
        message += "\nActual error: #{$!}\n" + $!.backtrace.inspect if @options && @options[:verbose]
        $stderr.puts message
      end

      # Loads the given command.
      def init
        super
        Index.update(:verbose=>true) if @options[:index]
        if @options[:load]
          Manager.load @options[:load], load_options
        elsif @options[:execute]
          define_autoloader
        else
          load_command_by_index
        end
      end

      #:stopdoc:
      def load_command_by_index
        Index.update(:verbose=>@options[:verbose]) if !@options[:index] && Boson.can_invoke?(@command) && !@options[:help]
        if !Boson.can_invoke?(@command) && ((lib = Index.find_library(@command)) ||
          (Index.update(:verbose=>@options[:verbose]) && (lib = Index.find_library(@command))))
          Manager.load lib, load_options
        end
      end

      def default_libraries
        super + (Boson.repo.config[:bin_defaults] || [])
      end

      def execute_command
        command, subcommand = @command.include?('.') ? @command.split('.', 2) : [@command, nil]
        dispatcher = subcommand ? Boson.invoke(command) : Boson.main_object
        @args = @args.join(" ") if ((com = Boson::Command.find(@command)) && com.option_command?)
        render_output dispatcher.send(subcommand || command, *@args)
      rescue ArgumentError
        puts "Wrong number of arguments for #{@command}\n\n"
        print_command_help
      end

      def print_command_help
        Boson.invoke(:usage, @command, :verbose=>@options[:verbose])
      end

      def parse_args(args)
        @option_parser = OptionParser.new(GLOBAL_OPTIONS)
        options = @option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = @option_parser.non_opts
        [new_args.shift, options, new_args]
      end

      def render_output(output)
        if Scientist.global_options
          puts output.inspect unless Scientist.rendered
        else
          View.render(output)
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
          Boson.invoke :commands, "", :fields=>["name", "usage", "description"], :description=>false
        end
      end
      #:startdoc:
    end
  end
end