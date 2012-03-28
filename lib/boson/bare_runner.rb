module Boson
  # Base class for runners.
  class BareRunner
    DEFAULT_LIBRARIES = []
    # Default options for parse_args
    GLOBAL_OPTIONS = {
      help: { type: :boolean, desc: "Displays this help message" }
    }

    module API
      # Loads rc
      def start(*)
        @options ||= {}
        load_rc
      end

      # Default libraries loaded by init
      def default_libraries
        DEFAULT_LIBRARIES
      end

      def all_libraries
        default_libraries
      end

      # Loads default libraries
      def init
        Manager.load default_libraries, load_options
      end

      # Wrapper around abort
      def abort_with(message)
        abort message
      end
    end

    class<<self
      include API

      # Executes a command and handles invalid args
      def execute_command(cmd, args)
        Boson.full_invoke(cmd, args)
      rescue ArgumentError
        raise if !allowed_argument_error?($!, cmd, args)
        abort_with "'#{cmd}' was called incorrectly.\nUsage: " + Command.usage(cmd)
      rescue NoMethodError => err
        index = RUBY_ENGINE == 'rbx' ? 1 : 0
        raise if !err.backtrace[index].include?('`full_invoke')
        no_command_error cmd
      end

      # Use to abort when no command found
      def no_command_error(cmd)
        abort_with %[Could not find command "#{cmd}"]
      end

      # Determines if a user command argument error or an internal Boson one
      def allowed_argument_error?(err, cmd, args)
        msg = RUBY_ENGINE == 'rbx' && err.class == ArgumentError ?
          /given \d+, expected \d+/ : /wrong number of arguments/
        err.message[msg] && (cmd_obj = Command.find(cmd)) &&
          cmd_obj.incorrect_arg_size?(args)
      end

      def option_parser
        @option_parser ||= OptionParser.new(self::GLOBAL_OPTIONS)
      end

      private
      def parse_args(args)
        options = option_parser.parse(args.dup, :opts_before_args=>true)
        new_args = option_parser.non_opts
        [new_args[0], options, new_args[1..-1]]
      end

      def load_rc
        rc = ENV['BOSONRC'] || '~/.bosonrc'
        load(rc) if !rc.empty? && File.exists?(File.expand_path(rc))
      rescue StandardError, SyntaxError, LoadError => err
        warn "Error while loading #{rc}:\n"+
          "#{err.class}: #{err.message}\n    #{err.backtrace.join("\n    ")}"
      end

      def load_options
        {}
      end
    end
  end
end
