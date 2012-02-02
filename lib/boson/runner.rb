require 'boson'

module Boson
  # Defines a RunnerLibrary for use by executables as a simple way to map
  # methods to subcommands
  class Runner < BareRunner
    def self.inherited(mod)
      @help_added ||= add_command_help
      Inspector.enable all_classes: true, module: mod.singleton_class
    end

    def self.default_libraries
      [self]
    end

    def self.start(args=ARGV)
      ENV['BOSONRC'] ||= ''
      super
      init
      command, options, args = parse_args(args)

      if options[:help] || command.nil?
        display_default_usage
      else
        execute_command(command, args)
      end
    end

    def self.execute_command(cmd, args)
      Command.find(cmd) ? super : no_command_error(cmd)
    end

    def self.display_help(cmd)
      usage = cmd.basic_usage.empty? ? '' : " #{cmd.basic_usage}"
      puts "Usage: #{app_name} #{cmd.name}#{usage}", "\n"
      if cmd.options
        puts "Options:"
        puts cmd.option_parser.print_usage_table(no_headers: true)
      end
      puts "Description:\n  #{cmd.desc || 'TODO'}"
    end

    def self.display_default_usage
      commands = Boson.commands.sort_by(&:name).map {|c| [c.name, c.desc.to_s] }
      puts "Usage: #{app_name} COMMAND [ARGS]", "", "Available commands:",
        Util.format_table(commands)
    end

    def self.app_name
      File.basename($0).split(' ').first
    end

    private
    def self.add_command_help
      # Overrides Scientist' default help
      Scientist.extend(Module.new do
        def run_help_option(cmd)
          Boson::Runner.display_help(cmd)
        end
      end)

      # Ensure all commands have -h
      Command.extend(Module.new do
        def new_attributes(name, library)
          super.update(option_command: true)
        end
      end)
      # Ensure this is only called once
      true
    end
  end
end
