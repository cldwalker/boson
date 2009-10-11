require 'shellwords'
module Boson
  # Scientist redefines the methods of commands that have options and/or take global options. This redefinition
  # allows a command to receive its arguments normally or as a commandline app does. For a command's
  # method to be redefined correctly, its last argument _must_ expect a hash.
  #
  # Take for example this basic method/command with an options definition:
  #   options :level=>:numeric, :verbose=>:boolean
  #   def foo(arg='', options={})
  #     [arg, options]
  #   end
  #
  # When Scientist wraps around foo(), argument defaults are respected:
  #    foo '', :verbose=>true   # normal call
  #    foo '-v'                 # commandline call
  #
  #    Both calls return: ['', {:verbose=>true}]
  #
  # Non-string arguments can be passed in:
  #    foo Object, :level=>1
  #    foo Object, 'l1'
  #
  #    Both calls return: [Object, {:level=>1}]
  #
  # === Global Options
  # Any command with options comes with default global options. For example '-hv' on such a command
  # prints a help summarizing a command's options as well as the global options.
  # When using global options along with command options, global options _must_ precede command options.
  # Take for example using the global --pretend option with the method above:
  #   irb>> foo '-p -l=1'
  #   Arguments: ["", {:level=>1}]
  #   Global options: {:pretend=>true}
  #
  # If a global option conflicts with a command's option, the command's option takes precedence. You can get around
  # this by passing a --global option which takes a string of options without their dashes. For example:
  #   foo '-p --fields=f1,f2 -l=1'
  #   # is the same as
  #   foo ' -g "p fields=f1,f2" -l=1 '
  #
  # === Rendering Views With Global Options
  # Perhaps the most important global option is --render. This option toggles the rendering of your command's output
  # with Hirb[http://github.com/cldwalker/hirb]. Since Hirb can be customized to generate any view, this option allows
  # you toggle a predefined view for a command without embedding view code in your command!
  #
  # Here's a simple example, toggling Hirb's table view:
  #   # Defined in a library file:
  #   #@options {}
  #   def list(options={})
  #     [1,2,3]
  #   end
  #
  #   Using it in irb:
  #   >> list
  #   => [1,2,3]
  #   >> list '-r'
  #   +-------+
  #   | value |
  #   +-------+
  #   | 1     |
  #   | 2     |
  #   | 3     |
  #   +-------+
  #   3 rows in set
  #   => true
  #
  # To default to rendering a view for a command, add a render_options {method attribute}[link:classes/Boson/MethodInspector.html]
  # above list() along with any options you want to pass to your Hirb helper class. In this case, using '-r' gives you the
  # command's returned object instead of a formatted view!
  module Scientist
    extend self
    # Handles all Scientist errors.
    class Error < StandardError; end
    class EscapeGlobalOption < StandardError; end

    attr_reader :global_options, :rendered
    @no_option_commands ||= []
    GLOBAL_OPTIONS = {
      :help=>{:type=>:boolean, :desc=>"Display a command's help"},
      :render=>{:type=>:boolean, :desc=>"Toggle a command's default rendering behavior"},
      :verbose=>{:type=>:boolean, :desc=>"Increase verbosity for help, errors, etc."},
      :global=>{:type=>:string, :desc=>"Pass a string of global options without the dashes"},
      :pretend=>{:type=>:boolean, :desc=>"Display what a command would execute without executing it"}
    } #:nodoc:
    RENDER_OPTIONS = {
      :fields=>{:type=>:array, :desc=>"Displays fields in the order given"},
      :sort=>{:type=>:string, :desc=>"Sort by given field"},
      :class=>{:type=>:string, :desc=>"Hirb helper class which renders"},
      :reverse_sort=>{:type=>:boolean, :desc=>"Reverse a given sort"},
      :max_width=>{:type=>:numeric, :desc=>"Max width of a table"},
      :vertical=>{:type=>:boolean, :desc=>"Display a vertical table"}
    } #:nodoc:

    # Redefines a command's method for the given object.
    def create_option_command(obj, command)
      cmd_block = create_option_command_block(obj, command)
      @no_option_commands << command if command.options.nil?
      [command.name, command.alias].compact.each {|e|
        obj.instance_eval("class<<self;self;end").send(:define_method, e, cmd_block)
      }
    end

    # The actual method which replaces a command's original method
    def create_option_command_block(obj, command)
      lambda {|*args|
        Boson::Scientist.translate_and_render(obj, command, args) {|args| super(*args) }
      }
    end

    #:stopdoc:
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
          command_size, args_size = @args.size > command.arg_size ? [command.arg_size, @args.size] :
            [command.arg_size - 1, @args.size - 1]
          raise ArgumentError, "wrong number of arguments (#{args_size} for #{command_size})"
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
        args = caller.grep(/bin_runner.rb:/).empty? ? Shellwords.shellwords(@args.pop) : @args
        parsed_options, new_args = parse_options args
        @args += new_args
      # add default options
      elsif (!@command.has_splat_args? && @args.size <= @command.arg_size - 1) ||
        (@command.has_splat_args? && !@args[-1].is_a?(Hash))
          parsed_options = parse_options([])[0]
      # merge default options with given hash of options
      elsif (@command.has_splat_args? || (@args.size == @command.arg_size)) && @args[-1].is_a?(Hash)
        parsed_options = parse_options([])[0]
        parsed_options.merge!(@args.pop)
      end
      parsed_options
    end

    def parse_options(args)
      parsed_options = @command.option_parser.parse(args, :delete_invalid_opts=>true)
      @global_options = option_parser.parse @command.option_parser.leading_non_opts
      new_args = option_parser.non_opts.dup + @command.option_parser.trailing_non_opts
      if @global_options[:global]
        global_opts = Shellwords.shellwords(@global_options[:global]).map {|str|
          ((str[/^(.*?)=/,1] || str).length > 1 ? "--" : "-") + str }
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
    #:startdoc:
  end
end