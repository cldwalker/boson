module Boson
  class BinRunner < Runner
    GLOBAL_OPTIONS =  {
      :verbose=>{:type=>:boolean, :desc=>"Verbose description of loading libraries or help"},
      :index=>{:type=>:boolean, :desc=>"Updates index"},
      :execute=>{:type=>:string, :desc=>"Executes given arguments as a one line script"},
      :repl=>{:type=>:boolean, :desc=>"Drops into irb or another given repl/shell with default and explicit libraries loaded"},
      :help=>{:type=>:boolean, :desc=>"Displays this help message or a command's help if given a command"},
      :load=>{:type=>:array, :values=>all_libraries, :enum=>false, :desc=>"A comma delimited array of libraries to load"}
    }

    class <<self
      attr_accessor :command
      def start(args=ARGV)
        @command, @options, @args = parse_args(args)
        return print_usage if args.empty? || (@command.nil? && !@options[:repl] && !@options[:execute])
        return ReplRunner.bin_start(@options[:repl], @options[:load]) if @options[:repl]
        init

        if @options[:help]
          print_command_help
        elsif @options[:execute]
          Boson.main_object.instance_eval @options[:execute]
        else
          execute_command
        end
      rescue Exception
        message = ($!.is_a?(NameError) && !@command.nil?) ?
          "Error: Command '#{@command}' not found" : "Error: #{$!.message}"
        message += "\nActual error: #{$!}\n" + $!.backtrace.inspect if @options && @options[:verbose]
        $stderr.puts message
      end

      def init
        super
        Index.update(:verbose=>true) if @options[:index]
        if @options[:load]
          Library.load @options[:load], load_options
        elsif @options[:execute]
          define_autoloader
        else
          load_command_by_index
        end
      end

      def load_command_by_index
        Index.update(:verbose=>@options[:verbose]) if !@options[:index] && command_defined?(@command) && !@options[:help]
        if !command_defined?(@command) && ((lib = Index.find_library(@command)) ||
          (Index.update(:verbose=>@options[:verbose]) && (lib = Index.find_library(@command))))
          Library.load_library lib, load_options
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

      def command_defined?(command)
        Boson.main_object.respond_to? command
      end

      def parse_args(args)
        @option_parser = OptionParser.new(GLOBAL_OPTIONS)
        options = @option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = @option_parser.non_opts
        [new_args.shift, options, new_args]
      end

      def render_output(output)
        if Higgs.global_options
          puts output.inspect unless Higgs.rendered
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
          Library.load [Boson::Commands::Core]
          puts "\n\nDEFAULT COMMANDS"
          Boson.invoke :commands, "", :fields=>["name", "usage", "description"], :description=>false
        end
      end
    end
  end
end