module Boson
  # Scientist wraps around and redefines an object's method to give it the following features:
  # * Methods can act like shell commands while still receiving ruby arguments normally. See the Commandification
  #   section.
  # * Methods can be commandified because they can have options. All methods have global options and can have render options
  #   or local options depending on what method attributes it has. See OptionCommand.
  # * Methods can have filter methods run on its return value before being returned TODO.
  # * Methods can have any number of optional views associated with them via render options (see View). Views can be toggled
  #   on/off with the global option --render (see OptionCommand).
  #
  # The main methods this module provides are redefine_command() for redefining an object's method with a Command object
  # and commandify() for redefining with a hash of method attributes. Note that for an object's method to be redefined correctly,
  # its last argument _must_ expect a hash.
  #
  # === Commandification
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
  module Scientist
    extend self
    # Handles all Scientist errors.
    class Error < StandardError; end
    class EscapeGlobalOption < StandardError; end

    attr_accessor :global_options, :rendered
    @no_option_commands ||= []
    @option_commands ||= {}

    # Redefines an object's method with a Command of the same name.
    def redefine_command(obj, command)
      cmd_block = redefine_command_block(obj, command)
      @no_option_commands << command if command.options.nil?
      [command.name, command.alias].compact.each {|e|
        obj.instance_eval("class<<self;self;end").send(:define_method, e, cmd_block)
      }
    end

    # A wrapper around redefine_command that doesn't depend on a Command object. Rather you
    # simply pass a hash of command attributes (see Command.new) or command methods and let OpenStruct mock a command.
    # The only required attribute is :name, though to get any real use you should define :options and
    # :arg_size (default is '*'). Example:
    #   >> def checkit(*args); args; end
    #   => nil
    #   >> Boson::Scientist.commandify(self, :name=>'checkit', :options=>{:verbose=>:boolean, :num=>:numeric})
    #   => ['checkit']
    #   # regular ruby method
    #   >> checkit 'one', 'two', :num=>13, :verbose=>true
    #   => ["one", "two", {:num=>13, :verbose=>true}]
    #   # commandline ruby method
    #   >> checkit 'one two -v -n=13'
    #   => ["one", "two", {:num=>13, :verbose=>true}]
    def commandify(obj, hash)
      raise ArgumentError, ":name required" unless hash[:name]
      hash[:arg_size] ||= '*'
      hash[:has_splat_args?] = true if hash[:arg_size] == '*'
      fake_cmd = OpenStruct.new(hash)
      fake_cmd.option_parser ||= OptionParser.new(fake_cmd.options || {})
      redefine_command(obj, fake_cmd)
    end

    # The actual method which redefines a command's original method
    def redefine_command_block(obj, command)
      lambda {|*args|
        Boson::Scientist.translate_and_render(obj, command, args) {|args| super(*args) }
      }
    end

    #:stopdoc:
    def option_command(cmd=@command)
      @option_commands[cmd] ||= OptionCommand.new(cmd)
    end

    def translate_and_render(obj, command, args)
      @global_options, @command = {}, command
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
      option_command.prepend_default_option(args)
      @global_options, parsed_options, args = option_command.parse(args)
      raise EscapeGlobalOption if @global_options[:help]
      if parsed_options
        option_command.add_default_args(args, obj)
        return args if @no_option_commands.include?(command)
        args << parsed_options
        option_command.check_argument_size(args)
      end
      args
    rescue Error, ArgumentError, EscapeGlobalOption
      raise
    rescue Exception
      message = @global_options[:verbose] ? "#{$!}\n#{$!.backtrace.inspect}" : $!.message
      raise Error, message
    end

    def render_or_raw(result)
      if (@rendered = render?)
        result = run_pipe_commands(result)
        View.render(result, OptionCommand.delete_non_render_options(@global_options.dup), false)
      else
        result = View.search_and_sort(result, @global_options) if !(@global_options.keys & [:sort, :reverse_sort, :query]).empty?
        run_pipe_commands(result)
      end
    rescue Exception
      message = @global_options[:verbose] ? "#{$!}\n#{$!.backtrace.inspect}" : $!.message
      raise Error, message
    end

    def pipe_options
      @pipe_options ||= Hash[*OptionCommand.default_global_options.select {|k,v| v[:pipe] }.flatten]
    end

    def run_pipe_commands(result)
      (global_options.keys & pipe_options.keys).each {|e|
        command = pipe_options[e][:pipe] != true ? pipe_options[e][:pipe] : e
        pipe_result = pipe_options[e][:type] == :boolean ? Boson.invoke(command, result) :
          Boson.invoke(command, result, global_options[e])
        result = pipe_result if pipe_options[e][:filter]
      }
      result
    end

    def render?
      !!@command.render_options ^ @global_options[:render]
    end
    #:startdoc:
  end
end