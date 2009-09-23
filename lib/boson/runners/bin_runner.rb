module Boson
  class BinRunner < Runner
    class <<self
      def start(args=ARGV)
        @command, @options, @args = parse_args(args)
        return print_usage if args.empty? || (@command.nil? && !@options[:repl] && !@options[:execute])
        return ReplRunner.bin_start(@options[:repl], @options[:load]) if @options[:repl]
        return $stderr.puts("Error: Command #{@command} not found.") unless init

        if @options[:help]
          print_command_help
        elsif @options[:execute]
          Boson.main_object.instance_eval @options[:execute]
        else
          execute_command
        end
      rescue Exception
        $stderr.puts "Error: #{$!.message}"
        $stderr.puts $!.backtrace.inspect if @options && @options[:verbose]
      end

      def init
        super
        Library.load boson_libraries, load_options
        @options[:load] ? load_command_by_option : (@options[:execute] ? define_autoloader :
          load_command_by_index)
        @options[:execute] || command_defined?(@command[/\w+/])
      end

      def execute_command
        command, subcommand = @command.include?('.') ? @command.split('.', 2) : [@command, nil]
        dispatcher = subcommand ? Boson.invoke(command) : Boson.main_object
        output = dispatcher.send(subcommand || command, *@args)
        render_output(output)
      rescue ArgumentError
        puts "Wrong number of arguments for #{@command}\n\n"
        print_command_help
      end

      def print_command_help
        puts Boson.invoke('usage', @command)
      end

      def command_defined?(command)
        Boson.main_object.respond_to? command
      end

      def load_command_by_option
        Library.load @options[:load], load_options
      end

      def load_command_by_index
        Index.update(:verbose=>@options[:index]) if @options[:index] || (command_defined?(@command) && !@options.key?(:help))
        if !command_defined?(@command) && ((lib = Index.find_library(@command)) ||
          (Index.update(:verbose=>@options[:verbose]) && (lib = Index.find_library(@command))))
          Library.load_library lib, load_options
        end
      end

      def load_options
        @load_options ||= {:verbose=>@options[:verbose]}
      end

      def default_options
        {:verbose=>:boolean, :index=>:boolean, :execute=>:string,:repl=>:boolean, :help=>:boolean,
          :load=>{:type=>:array, :values=>all_libraries, :enum=>false}}
      end

      def option_descriptions
        {
          :verbose=>"Verbose description of loading libraries or help",
          :index=>"Forces index update before looking for a command",
          :execute=>"Executes given arguments as a one line script",
          :load=>"A comma delimited array of libraries to load",
          :repl=>"Drops into irb or another given repl/shell with default and explicit libraries loaded",
          :help=>"Displays this help message or a command's help if given a command"
        }
      end

      def parse_args(args)
        @option_parser = OptionParser.new(default_options)
        options = @option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = @option_parser.non_opts
        [new_args.shift, options, new_args]
      end

      def render_output(output)
        return if output.nil?
        if output.is_a?(Array)
          Boson.invoke :render, output
        else
          puts Hirb::View.render_output(output) || output
        end
      end

      def print_usage
        puts "boson [GLOBAL OPTIONS] [COMMAND] [ARGS] [COMMAND OPTIONS]\n\n"
        puts "GLOBAL OPTIONS"
        aliases = @option_parser.opt_aliases.invert
        option_help = option_descriptions.sort_by {|k,v| k.to_s }.map {|e| ["--#{e[0]}", aliases["--#{e[0]}"], e[1]] }
        Library.load [Boson::Commands::Core]
        Boson.invoke :render, option_help, :headers=>["Option", "Alias", "Description"], :description=>false
        if @options[:verbose]
          puts "\n\nDEFAULT COMMANDS"
          Boson.invoke :commands, "", :fields=>["name", "usage", "description"], :description=>false
        end
      end
    end
  end
end