require 'shellwords'
module Boson
  # A class used by Scientist to wrap around Command objects. It's main purpose is to parse
  # a command's global and local options.
  # As the names imply, global options are available to all commands while local options are specific to a command.
  # When passing options to commands, global ones _must_ be passed first, then local ones.
  # Also, options _must_ all be passed either before or after arguments.
  #
  # === Basic Global Options
  # Any command with options comes with basic global options. For example '-hv' on an option command
  # prints a help summarizing global and local options. Another basic global option is --pretend. This
  # option displays what global options have been parsed and the actual arguments to be passed to a
  # command if executed. For example:
  #
  #   # Define this command in a library
  #   options :level=>:numeric, :verbose=>:boolean
  #   def foo(*args)
  #     args
  #   end
  #
  #   irb>> foo 'testin -p -l=1'
  #   Arguments: ["testin", {:level=>1}]
  #   Global options: {:pretend=>true}
  #
  # If a global option conflicts with a local option, the local option takes precedence. You can get around
  # this by passing global options after a '-'. For example, if the global option -f (--fields) conflicts with
  # a local -f (--force):
  #   foo 'arg1 -v -f - -f=f1,f2'
  #   # is the same as
  #   foo 'arg1 -v --fields=f1,f2 -f'
  #
  class OptionCommand
    # ArgumentError specific to @command's arguments
    class CommandArgumentError < ::ArgumentError; end

    BASIC_OPTIONS = {
      :help=>{:type=>:boolean, :desc=>"Display a command's help"},
      :verbose=>{:type=>:boolean, :desc=>"Increase verbosity for help, errors, etc."},
      :pretend=>{:type=>:boolean, :desc=>"Display what a command would execute without executing it"},
    } #:nodoc:

    class <<self
      def default_option_parser
        @default_option_parser ||= OptionParser.new default_options
      end

      module API
        def default_options
          BASIC_OPTIONS
        end
      end
      include API
    end

    attr_accessor :command
    def initialize(cmd)
      @command = cmd
    end

    # Parses arguments and returns global options, local options and leftover arguments.
    def parse(args)
      if args.size == 1 && args[0].is_a?(String)
        global_opt, parsed_options, args = parse_options Shellwords.shellwords(args[0])
      # last string argument interpreted as args + options
      elsif args.size > 1 && args[-1].is_a?(String)
        temp_args = Boson.in_shell ? args : Shellwords.shellwords(args.pop)
        global_opt, parsed_options, new_args = parse_options temp_args
        Boson.in_shell ? args = new_args : args += new_args
      # add default options
      elsif @command.options.nil? || @command.options.empty? || (!@command.has_splat_args? &&
        args.size <= (@command.arg_size - 1).abs) || (@command.has_splat_args? && !args[-1].is_a?(Hash))
          global_opt, parsed_options = parse_options([])[0,2]
      # merge default options with given hash of options
      elsif (@command.has_splat_args? || (args.size == @command.arg_size)) && args[-1].is_a?(Hash)
        global_opt, parsed_options = parse_options([])[0,2]
        parsed_options.merge!(args.pop)
      end
      [global_opt || {}, parsed_options, args]
    end

    #:stopdoc:
    def parse_options(args)
      parsed_options = @command.option_parser.parse(args, :delete_invalid_opts=>true)
      trailing, unparseable = split_trailing
      global_options = parse_global_options @command.option_parser.leading_non_opts + trailing
      new_args = option_parser.non_opts.dup + unparseable
      [global_options, parsed_options, new_args]
    rescue OptionParser::Error
      global_options = parse_global_options @command.option_parser.leading_non_opts + split_trailing[0]
      global_options[:help] ? [global_options, nil, []] : raise
    end

    def split_trailing
      trailing = @command.option_parser.trailing_non_opts
      if trailing[0] == '--'
        trailing.shift
        [ [], trailing ]
      else
        trailing.shift if trailing[0] == '-'
        [ trailing, [] ]
      end
    end

    def parse_global_options(args)
      option_parser.parse args
    end

    module API
      def option_parser
        @option_parser ||= self.class.default_option_parser
      end
    end
    include API

    def modify_args(args)
      if @command.default_option && @command.arg_size <= 1 && !@command.has_splat_args? &&
        !args[0].is_a?(Hash) && args[0].to_s[/./] != '-' && !args.join.empty?
        args[0] = "--#{@command.default_option}=#{args[0]}"
      end
    end

    def check_argument_size(args)
      if args.size != @command.arg_size && !@command.has_splat_args?
        command_size, args_size = args.size > @command.arg_size ? [@command.arg_size, args.size] :
          [@command.arg_size - 1, args.size - 1]
        raise CommandArgumentError, "wrong number of arguments (#{args_size} for #{command_size})"
      end
    end

    def add_default_args(args, obj)
      if @command.args && args.size < @command.args.size - 1
        # leave off last arg since its an option
        @command.args.slice(0..-2).each_with_index {|arr,i|
          next if args.size >= i + 1 # only fill in once args run out
          break if arr.size != 2 # a default arg value must exist
          begin
            args[i] = @command.file_parsed_args? ? obj.instance_eval(arr[1]) : arr[1]
          rescue Exception
            raise Scientist::Error, "Unable to set default argument at position #{i+1}.\nReason: #{$!.message}"
          end
        }
      end
    end
    #:startdoc:
  end
end
