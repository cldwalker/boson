module Boson
  # Scientist wraps around and redefines an object's method to give it the following features:
  # * Methods can take shell command input with options or receive its normal arguments. See the Commandification
  #   section.
  # * Methods have a slew of global options available. See OptionCommand for an explanation of basic global options.
  # * Before a method returns its value, it pipes its return value through pipe commands if pipe options are specified. See Pipe.
  # * Methods can have any number of optional views associated with them via global render options (see View). Views can be toggled
  #   on/off with the global option --render (see OptionCommand).
  #
  # The main methods Scientist provides are redefine_command() for redefining an object's method with a Command object
  # and commandify() for redefining with a hash of method attributes. Note that for an object's method to be redefined correctly,
  # its last argument _must_ expect a hash.
  #
  # === Commandification
  # Take for example this basic method/command with an options definition:
  #   options :level=>:numeric, :verbose=>:boolean
  #   def foo(*args)
  #     args
  #   end
  #
  # When Scientist wraps around foo(), it can take arguments normally or as a shell command:
  #    foo 'one', 'two', :verbose=>true   # normal call
  #    foo 'one two -v'                 # commandline call
  #
  #    Both calls return: ['one', 'two', {:verbose=>true}]
  #
  # Non-string arguments can be passed as well:
  #    foo Object, 'two', :level=>1
  #    foo Object, 'two -l1'
  #
  #    Both calls return: [Object, 'two', {:level=>1}]
  module Scientist
    extend self
    # Handles all Scientist errors.
    class Error < StandardError; end

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
      option_command.prepend_default_option(args)
      @global_options, parsed_options, args = option_command.parse(args)
      if @global_options[:help]
        Boson.invoke(:usage, command.name, :verbose=>@global_options[:verbose])
      else
        args = modify_args(parsed_options, obj, command, args) if parsed_options
        run_pretend_option(args)
        render_or_raw yield(args) unless @global_options[:pretend]
      end
    rescue OptionCommand::CommandArgumentError
      run_pretend_option(args ||= [])
      raise unless @global_options[:pretend]
    rescue OptionParser::Error, Error
      message = @global_options[:verbose] ? "#{$!}\n#{$!.backtrace.inspect}" : $!.message
      $stderr.puts "Error: " + message
    end

    def run_pretend_option(args)
      if @global_options[:verbose] || @global_options[:pretend]
        puts "Arguments: #{args.inspect}", "Global options: #{@global_options.inspect}"
      end
      @rendered = true if @global_options[:pretend]
    end

    def modify_args(parsed_options, obj, command, args)
      option_command.add_default_args(args, obj)
      return args if @no_option_commands.include?(command)
      args << parsed_options
      option_command.check_argument_size(args)
      args
    end

    def render_or_raw(result)
      if (@rendered = render?)
        result = Pipe.process(result, @global_options) if @global_options.key?(:class) ||
          @global_options.key?(:method)
        View.render(result, OptionCommand.delete_non_render_options(@global_options.dup), false)
      else
        Pipe.process(result, @global_options)
      end
    rescue StandardError
      message = @global_options[:verbose] ? "#{$!}\n#{$!.backtrace.inspect}" : $!.message
      raise Error, message
    end

    def render?
      !!@command.render_options ^ @global_options[:render]
    end
    #:startdoc:
  end
end