require 'shellwords'
module Boson
  module Higgs
    extend self

    def create_option_command(obj, command)
      cmd_block = create_option_command_block(command)
      [command.name, command.alias].compact.each {|e|
        obj.instance_eval("class<<self;self;end").send(:define_method, e, cmd_block)
      }
    end

    def create_option_command_block(command)
      options = command.options.delete(:options) || {}
      default_lambda = lambda {|*args|
        begin
        if args.size == 1 && args[0].is_a?(String)
          args = Shellwords.shellwords(args.join(" "))
          parsed_options = command.option_parser.parse(args, :delete_invalid_opts=>true)
          args = command.option_parser.non_opts
        # last string argument interpreted as args + options
        elsif args.size > 1 && args[-1].is_a?(String)
          parsed_options = command.option_parser.parse(args.pop.split(/\s+/), :delete_invalid_opts=>true)
          args += command.option_parser.non_opts
        # default options
        elsif command.args && args.size <= command.args.size - 1
          parsed_options = command.option_parser.parse([], :delete_invalid_opts=>true)
        end
        if parsed_options
          # add in default values from command.args
          if command.args && args.size < command.args.size - 1
            # leave off last arg since its an option
            command.args.slice(0..-2).each_with_index {|arr,i|
              next if args.size >= i + 1 # only fill in once args run out
              break if arr.size != 2 # a default arg value must exist
              begin
                args[i] = command.file_parsed_args? ? Boson.main_object.instance_eval(arr[1]) : arr[1]
              rescue Exception
              end
            }
          end
          args << parsed_options
          if command.args && args.size < command.args.size && !command.has_splat_args?
            raise ArgumentError, "wrong number of arguments (#{args.size} for #{command.args.size})"
          end
        end
        super(*args)
        rescue OptionParser::Error
          $stderr.puts "Error: " + $!.message
        end
      }
    end
  end
end