module Boson
  # Base class for runners.
  class BareRunner
    DEFAULT_LIBRARIES = []
    GLOBAL_OPTIONS = {
      help: {
        type: :boolean,
        desc: "Displays this help message or a command's help if given a command"
      }
    }

    module API
      def start(*)
        @options ||= {}
        load_rc
      end

      # Returns true if in commandline with verbose flag or if set explicitly.
      # Useful in plugins.
      def verbose?
        @verbose
      end

      # Default libraries loaded by init
      def default_libraries
        DEFAULT_LIBRARIES
      end

      def all_libraries
        default_libraries
      end
    end

    class<<self
      include API

      # Loads default libraries
      def init
        Manager.load default_libraries, load_options
      end

      def load_rc
        rc = ENV['BOSONRC'] || '~/.bosonrc'
        load(rc) if !rc.empty? && File.exists?(File.expand_path(rc))
      rescue StandardError, SyntaxError, LoadError => err
        warn "Error while loading #{rc}:\n"+
          "#{err.class}: #{err.message}\n    #{err.backtrace.join("\n    ")}"
      end

      def execute_command(cmd, args)
        Boson.full_invoke(cmd, args)
      rescue ArgumentError
        if allowed_argument_error?($!, cmd, args)
          abort_with "'#{cmd}' was called incorrectly.\n" + Command.usage(cmd)
        else
          raise
        end
      end

      def abort_with(message)
        abort message
      end

      def allowed_argument_error?(err, cmd, args)
        (err.message[/wrong number of arguments/] &&
          (cmd_obj = Command.find(cmd)) && cmd_obj.arg_size != args.size)
      end

      def parse_args(args)
        @option_parser = OptionParser.new(self::GLOBAL_OPTIONS)
        options = @option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = @option_parser.non_opts
        [new_args[0], options, new_args[1..-1]]
      end

      def verbose=(val)
        @verbose = val
      end

      def load_options
        {:verbose=>@options[:verbose]}
      end
    end
  end
end
