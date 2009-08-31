module Boson
  class BinRunner < Runner
    class <<self
      def init(options={})
        super
        Library.load boson_libraries
        if options.delete(:index)
          if index && (found = index.find {|lib, commands| commands.include?(@full_command) })
            Library.load_library found[0], options
          end
          true
        else
          options[:quick_discover] ? quick_discover_command(@command, options) : discover_command(@command, options)
        end
      end

      def default_options
        {:quick_discover=>false, :verbose=>true, :index=>false}
      end

      def quick_discover_command(command, options)
        libraries_to_load.find {|e|
          if (lib = Library.quick_load(e, options)) && lib.commands.include?(command)
            lib.load_dependencies
            lib.after_load(options)
          end
          Boson.main_object.respond_to? command
        }
      end

      def discover_command(command, options)
        libraries_to_load.find {|e|
          Library.load [e], options
          Boson.main_object.respond_to? command
        }
      end

      def libraries_to_load
        all_libraries.partition {|e| e =~ /^#{@command}/ }.flatten
      end

      def start(args=ARGV)
        return print_usage if args.empty?
        @command, @options, @args = parse_args(args)
        process_options
        @full_command = @command
        @command, @subcommand = @command.split('.', 2) if @command.include?('.')
        if init @options
          dispatcher = @subcommand ? Boson.invoke(@command) : Boson.main_object
          output = dispatcher.send(@subcommand || @command, *@args)
          render_output(output)
        else
          $stderr.puts "Error: Command #{@command} not found."
        end
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
        puts Hirb::View.render_output(output) || output.inspect
      end

      def print_usage
        puts "boson [COMMAND] [ARGS]"
      end
    end
  end
end