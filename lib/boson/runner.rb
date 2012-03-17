require 'boson'

module Boson
  # Defines a RunnerLibrary for use by executables as a simple way to map
  # methods to subcommands
  class Runner < BareRunner
    # Stores currently started Runner subclass
    class <<self; attr_accessor :current; end

    def self.inherited(mod)
      @help_added ||= add_command_help
      Inspector.enable all_classes: true, module: mod.singleton_class
    end

    def self.default_libraries
      [self, DefaultCommandsRunner]
    end

    def self.start(args=ARGV)
      Runner.current = self
      Boson.in_shell = true
      ENV['BOSONRC'] ||= ''
      super
      init
      command, options, args = parse_args(args)
      execute command, args, options
    end

    def self.execute(command, args, options)
      options[:help] || command.nil? ? display_help :
        execute_command(command, args, options)
    end

    def self.execute_command(cmd, args, options)
      Command.find(cmd) ? super(cmd, args) : no_command_error(cmd)
    end

    def self.display_command_help(cmd)
      puts "Usage: #{app_name} #{cmd.name} #{cmd.basic_usage}".rstrip, ""
      if cmd.options
        puts "Options:"
        cmd.option_parser.print_usage_table(no_headers: true)
        puts ""
      end
      puts "Description:\n  #{cmd.desc || 'TODO'}"
    end

    def self.display_help
      commands = Boson.commands.sort_by(&:name).map {|c| [c.name, c.desc.to_s] }
      puts "Usage: #{app_name} COMMAND [ARGS]", "", "Available commands:",
        Util.format_table(commands)
    end

    def self.app_name
      File.basename($0).split(' ').first
    end

    private
    def self.load_options
      {force: true}
    end

    def self.add_command_help
      Scientist.extend(ScientistExtension)
      Command.extend(CommandExtension)
      true # Ensure this method is only called once
    end

    module ScientistExtension
      # Overrides Scientist' default help
      def run_help_option(cmd)
        Boson::Runner.current.display_command_help(cmd)
      end
    end

    module CommandExtension
      # Ensure all commands have -h
      def new_attributes(name, library)
        super.update(option_command: true)
      end
    end
  end

  # Defines default commands that are available to executables i.e. Runner.start
  class DefaultCommandsRunner < Runner
    desc "Displays help for a command"
    def help(cmd)
      (cmd_obj = Command.find(cmd)) ? Runner.current.display_command_help(cmd_obj) :
        self.class.no_command_error(cmd)
    end
  end
end
