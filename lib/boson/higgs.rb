require 'shellwords'
module Boson
  module Higgs
    extend self
    class Error < StandardError; end
    class ThrowGlobalOption < StandardError; end

    def create_option_command(obj, command)
      cmd_block = create_option_command_block(obj, command)
      [command.name, command.alias].compact.each {|e|
        obj.instance_eval("class<<self;self;end").send(:define_method, e, cmd_block)
      }
    end

    def create_option_command_block(obj, command)
      lambda {|*args|
        Boson::Higgs.translate_and_render(obj, command, args) {|args| super(*args) }
      }
    end

    def translate_and_render(obj, command, args)
      args = translate_args(obj, command, args)
      render yield(args)
    rescue ThrowGlobalOption
      Boson.invoke(:usage, command.name) if global_options[:help]
    rescue OptionParser::Error, Error
      $stderr.puts "Error: " + $!.message
    end

    def translate_args(obj, command, args)
      @obj, @command = obj, command
      if parsed_options = command_options(args)
        add_default_args(args)
        args << parsed_options
        if args.size != command.arg_size && !command.has_splat_args?
          command_size = args.size > command.arg_size ? command.arg_size : command.arg_size - 1
          raise ArgumentError, "wrong number of arguments (#{args.size - 1} for #{command_size})"
        end
      end
      args
    rescue Error, ArgumentError, ThrowGlobalOption
      raise
    rescue Exception
      raise Error, $!.message
    end

    def render(result)
      render? ? Boson.invoke(:render, result, global_render_options) : result
    rescue Exception
      raise Error, $!.message
    end

    def option_parser
      @command.render_options ? command_option_parser : default_option_parser
    end

    def command_option_parser
      (@option_parsers ||= {})[@command] ||= begin
        OptionParser.new Util.recursive_hash_merge(default_options, @command.render_options)
      end
    end

    def default_option_parser
      @default_option_parser ||= OptionParser.new(default_options)
    end

    def default_options
      {:help=>:boolean, :render=>:boolean, :debug=>:boolean}.merge(render_options)
    end

    def render_options
      {:fields=>{:type=>:array}, :sort=>{:type=>:string}, :as=>:string, :reverse_sort=>:boolean}
    end

    def global_render_options
      global_options.dup.delete_if {|k,v| !render_options.keys.include?(k) }
    end

    def render?
      (@command.render_options && !global_options[:render]) || (!@command.render_options && global_options[:render])
    end

    def global_options
      @global_options ||= {}
    end

    def command_options(args)
      if args.size == 1 && args[0].is_a?(String)
        args.replace Shellwords.shellwords(args.join(" "))
        parsed_options, new_args = parse_options args
        args.replace new_args
      # last string argument interpreted as args + options
      elsif args.size > 1 && args[-1].is_a?(String)
        parsed_options, new_args = parse_options args.pop.split(/\s+/)
        args.replace args + new_args
      # default options
      elsif (args.size <= @command.arg_size - 1) || (@command.has_splat_args? && !args[-1].is_a?(Hash))
        parsed_options, new_args = parse_options []
      end
      parsed_options
    end

    def parse_options(args)
      parsed_options = @command.option_parser.parse(args, :delete_invalid_opts=>true)
      @global_options = option_parser.parse @command.option_parser.leading_non_opts
      raise ThrowGlobalOption if @global_options[:help]
      new_args = (option_parser.non_opts + @command.option_parser.non_opts).uniq
      [parsed_options, new_args]
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
            raise Error, "Unable to set default argument at position #{i+1}.\nReason: #{$!.message}"
          end
        }
      end
    end
  end
end