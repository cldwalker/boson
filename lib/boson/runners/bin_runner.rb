module Boson
  class BinRunner < Runner
    class <<self
      def start(args=ARGV)
        @command, @options, @args = parse_args(args)
        return print_usage if args.empty? || (!@options[:repl] && @command.nil?)
        @options[:repl] ? ReplRunner.bin_start(@options[:repl], unalias_libraries(@options[:load])) : load_command
      rescue OptionParser::Error
        $stderr.puts "Error: "+ $!.message
      end

      def load_command
        @original_command = @command
        @command, @subcommand = @command.split('.', 2) if @command.include?('.')
        if init || @options[:execute]
          execute_command
        else
          $stderr.puts "Error: Command #{@command} not found."
        end
      end

      def execute_command
        if @options[:help]
          print_command_help
        elsif @options[:execute]
          Boson.main_object.instance_eval "#{@original_command} #{@args.join(' ')}"
        else
          dispatcher = @subcommand ? Boson.invoke(@command) : Boson.main_object
          output = dispatcher.send(@subcommand || @command, *@args)
          render_output(output)
        end
      rescue ArgumentError
        puts "Incorrect number of arguments given"
        print_command_help
      end

      def print_command_help
        puts Boson.invoke('usage', @command)
      end

      def init
        super
        Library.load boson_libraries, load_options
        @options[:load] ? load_command_by_option : (@options[:discover] ?
          load_command_by_discovery : load_command_by_index)
        command_defined? @command
      end

      def command_defined?(command)
        Boson.main_object.respond_to? command
      end

      def load_command_by_option
        Library.load unalias_libraries(@options[:load]), load_options
      end

      def load_command_by_index
        find_lambda = @subcommand ? method(:is_namespace_command) : lambda {|e| [e.name, e.alias].include?(@command)}
        load_index(@options[:index_create]) unless @command == 'index' && @subcommand.nil?
        if !command_defined?(@command) && (found = Boson.commands.find(&find_lambda))
          Library.load_library found.lib, load_options
        end
      end

      def load_options
        @load_options ||= {:verbose=>@options[:verbose]}
      end

      def load_index(force=false)
        if !File.exists?(marshal_file) || force
          puts "Indexing commands ..."
          index_commands(load_options)
        else
          marshal_read
        end
      end

      def is_namespace_command(cmd)
        [cmd.name, cmd.alias].include?(@subcommand) &&
        (command = Boson.commands.find {|f| f.name == @command && f.lib == 'namespace'} || Boson.command(@command, :alias)) &&
        cmd.lib[/\w+$/] == command.name
      end

      def default_options
        {:discover=>:boolean, :verbose=>:boolean, :index_create=>:boolean, :execute=>:boolean, :load=>:optional,
           :repl=>:boolean, :help=>:boolean}
      end

      def option_descriptions
        {:discover=>"Loads given command by loading libraries until it discovers the correct library",
          :verbose=>"Verbose description of loading libraries or help",
          :index_create=>"Loads/indexes all libraries before executing command",
          :execute=>"Executes given arguments as a one line script",
          :load=>"A comma delimited array of libraries to load",
          :repl=>"Drops into irb or another given repl/shell with default and explicit libraries loaded",
          :help=>"Displays this help message or a command's help if given a command"
        }
      end

      def load_command_by_discovery
        all_libraries.partition {|e| e =~ /^#{@command}/ }.flatten.find {|e|
          Library.load [e], load_options
          command_defined? @command
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
        shorts = @option_parser.shorts.invert
        option_help = option_descriptions.sort_by {|k,v| k.to_s }.map {|e| ["--#{e[0]}", shorts["--#{e[0]}"], e[1]] }
        Library.load [Boson::Commands::Core]
        Boson.invoke :render, option_help, :headers=>["Option", "Alias", "Description"]
        if @options[:verbose]
          puts "\n\nDEFAULT COMMANDS"
          Boson.invoke :commands, "", :fields=>["name", "usage", "description"]
        end
      end
    end
  end
end