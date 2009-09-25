require 'shellwords'
module Boson
  module Higgs
    extend self

    def create_option_command(obj, command)
      cmd_block = create_option_command_block(obj, command)
      [command.name, command.alias].compact.each {|e|
        obj.instance_eval("class<<self;self;end").send(:define_method, e, cmd_block)
      }
    end

    def create_option_command_block(obj, command)
      lambda {|*args|
        begin
          args = Boson::Higgs.translate_args(obj, command, args)
          super(*args)
        rescue OptionParser::Error
          $stderr.puts "Error: " + $!.message
        end
      }
    end

    def translate_args(obj, command, args)
      @obj, @command = obj, command
      if parsed_options = parse_options(args)
        add_default_args(args)
        args << parsed_options
        if args.size != command.arg_size && !command.has_splat_args?
          command_size = args.size > command.arg_size ? command.arg_size : command.arg_size - 1
          raise ArgumentError, "wrong number of arguments (#{args.size - 1} for #{command_size})"
        end
      end
      args
    end

    def parse_options(args)
      if args.size == 1 && args[0].is_a?(String)
        args.replace Shellwords.shellwords(args.join(" "))
        parsed_options = @command.option_parser.parse(args, :delete_invalid_opts=>true)
        args.replace @command.option_parser.non_opts
      # last string argument interpreted as args + options
      elsif args.size > 1 && args[-1].is_a?(String)
        parsed_options = @command.option_parser.parse(args.pop.split(/\s+/), :delete_invalid_opts=>true)
        args.replace args + @command.option_parser.non_opts
      # default options
      elsif (args.size <= @command.arg_size - 1) || (@command.has_splat_args? && !args[-1].is_a?(Hash))
        parsed_options = @command.option_parser.parse([], :delete_invalid_opts=>true)
      end
      parsed_options
    end

    def add_default_args(args)
      if @command.args && args.size < @command.args.size - 1
        # leave off last arg since its an option
        @command.args.slice(0..-2).each_with_index {|arr,i|
          next if args.size >= i + 1 # only fill in once args run out
          break if arr.size != 2 # a default arg value must exist
          begin
            args[i] = @command.file_parsed_args? ? @obj.instance_eval(arr[1]) : arr[1]
          rescue Exception
          end
        }
      end
    end
  end
end