require 'shellwords'
module Boson
  module Higgs
    extend self
    class Error < StandardError; end
    class EscapeGlobalOption < StandardError; end
    attr_reader :global_options, :rendered
    @no_option_commands ||= []
    GLOBAL_OPTIONS = {
      :help=>{:type=>:boolean, :desc=>"Display a command's help"},
      :render=>{:type=>:boolean, :desc=>"Toggle a command's default render behavior"},
      :verbose=>{:type=>:boolean, :desc=>"Increase verbosity for help, errors, etc."},
      :global=>{:type=>:string, :desc=>"Pass a string of global options without the dashes i.e. '-p -f=f1,f2' -> 'p f=f1,f2'"},
      :pretend=>{:type=>:boolean, :desc=>"Display what a command would execute without executing it"}
    }
    RENDER_OPTIONS = {
      :fields=>{:type=>:array, :desc=>"Displays fields in the order given"},
      :sort=>{:type=>:string, :desc=>"Sort by given field"},
      :as=>{:type=>:string, :desc=>"Hirb helper class which renders"},
      :reverse_sort=>{:type=>:boolean, :desc=>"Reverse a given sort"},
      :max_width=>{:type=>:numeric, :desc=>"Max width of a table"},
      :vertical=>{:type=>:boolean, :desc=>"Display a vertical table"}
    }

    def create_option_command(obj, command)
      cmd_block = create_option_command_block(obj, command)
      @no_option_commands << command if command.options.nil?
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
      @global_options = {}
      args = translate_args(obj, command, args)
      if @global_options[:verbose] || @global_options[:pretend]
        puts "Arguments: #{args.inspect}", "Global options: #{@global_options.inspect}"
      end
      return @rendered = true if @global_options[:pretend]
      render_or_raw yield(args)
    rescue EscapeGlobalOption
      Boson.invoke(:usage, command.name, :verbose=>@global_options[:verbose]) if @global_options[:help]
    rescue OptionParser::Error, Error
      $stderr.puts "Error: " + $!.message
    end

    def translate_args(obj, command, args)
      @obj, @command, @args = obj, command, args
      @command.options ||= {}
      if parsed_options = command_options
        add_default_args(@args)
        return @args if @no_option_commands.include?(@command)
        @args << parsed_options
        if @args.size != command.arg_size && !command.has_splat_args?
          command_size = @args.size > command.arg_size ? command.arg_size : command.arg_size - 1
          if @args.size - 1 == command_size
            raise Error, "Arguments are misaligned. Possible causes are incorrect argument "+
              "size or no argument for this method's options."
          else
            raise ArgumentError, "wrong number of arguments (#{@args.size - 1} for #{command_size})"
          end
        end
      end
      @args
    rescue Error, ArgumentError, EscapeGlobalOption
      raise
    rescue Exception
      message = @global_options[:verbose] ? "#{$!}\n#{$!.backtrace.inspect}" : $!.message
      raise Error, message
    end

    def render_or_raw(result)
      (@rendered = render?) ? View.render(result, global_render_options) : result
    rescue Exception
      message = @global_options[:verbose] ? "#{$!}\n#{$!.backtrace.inspect}" : $!.message
      raise Error, message
    end

    def option_parser
      @command.render_options ? command_option_parser : default_option_parser
    end

    def command_option_parser
      (@option_parsers ||= {})[@command] ||= OptionParser.new render_options.merge(GLOBAL_OPTIONS)
    end

    def render_option_parser(cmd)
      @command = cmd
      option_parser
    end

    def default_option_parser
      @default_option_parser ||= OptionParser.new RENDER_OPTIONS.merge(GLOBAL_OPTIONS)
    end

    def render_options
      @command.render_options ? command_render_options : RENDER_OPTIONS
    end

    def command_render_options
      (@command_render_options ||= {})[@command] ||= begin
        @command.render_options.each {|k,v|
          if !v.is_a?(Hash) && !v.is_a?(Symbol) && RENDER_OPTIONS.keys.include?(k)
            @command.render_options[k] = {:default=>v}
          end
        }
        opts = Util.recursive_hash_merge(@command.render_options, RENDER_OPTIONS)
        opts[:sort][:values] ||= opts[:fields][:values] if opts[:fields][:values]
        opts
      end
    end

    def global_render_options
      @global_options.dup.delete_if {|k,v| !render_options.keys.include?(k) }
    end

    def render?
      (@command.render_options && !@global_options[:render]) || (!@command.render_options && @global_options[:render])
    end

    def command_options
      if @args.size == 1 && @args[0].is_a?(String)
        parsed_options, @args = parse_options Shellwords.shellwords(@args[0])
      # last string argument interpreted as args + options
      elsif @args.size > 1 && @args[-1].is_a?(String)
        parsed_options, new_args = parse_options @args.pop.split(/\s+/)
        @args += new_args
      # default options
      elsif (@args.size <= @command.arg_size - 1) || (@command.has_splat_args? && !@args[-1].is_a?(Hash))
        parsed_options = parse_options([])[0]
      end
      parsed_options
    end

    def parse_options(args)
      parsed_options = @command.option_parser.parse(args, :delete_invalid_opts=>true)
      @global_options = option_parser.parse @command.option_parser.leading_non_opts
      new_args = option_parser.non_opts.dup + @command.option_parser.trailing_non_opts
      if @global_options[:global]
        global_opts = Shellwords.shellwords(@global_options[:global]).map {|str| (str.length > 1 ? "--" : "-") + str }
        @global_options.merge! option_parser.parse(global_opts)
      end
      raise EscapeGlobalOption if @global_options[:help]
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