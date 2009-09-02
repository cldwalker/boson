module Boson
  class BinRunner < Runner
    class <<self
      def start(args=ARGV)
        return print_usage if args.empty?
        @command, @options, @args = parse_args(args)
        process_options
        @original_command = @command
        @command, @subcommand = @command.split('.', 2) if @command.include?('.')
        if init || @options[:execute]
          execute_command
        else
          $stderr.puts "Error: Command #{@command} not found."
        end
      end

      def execute_command
        if @options[:execute]
          Boson.main_object.instance_eval "#{@original_command} #{@args.join(' ')}"
        else
          dispatcher = @subcommand ? Boson.invoke(@command) : Boson.main_object
          output = dispatcher.send(@subcommand || @command, *@args)
          render_output(output)
        end
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
        Library.load @options[:load].split(/\s*,\s*/), load_options
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
        {:discover=>false, :verbose=>false, :index_create=>false, :execute=>false, :load=>false}
      end

      def load_command_by_discovery
        all_libraries.partition {|e| e =~ /^#{@command}/ }.flatten.find {|e|
          Library.load [e], load_options
          command_defined? @command
        }
      end

      def process_options
        possible_options = default_options.keys
        @options.each {|k,v|
          if (match = possible_options.find {|e| e.to_s =~ /^#{k}/ })
            @options[match] = @options.delete(k)
          end
        }
        @options = default_options.merge(@options)
      end

      # taken from rip
      def parse_args(args)
        options, args = args.partition { |piece| piece =~ /^-/ }
        command = args.shift
        options = options.inject({}) do |hash, flag|
          key, value = flag.split('=')
          hash[key.sub(/^--?/,'').intern] = value.nil? ? true : value
          hash
        end
        [command, options, args]
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
        puts "boson [COMMAND] [ARGS]"
      end
    end
  end
end