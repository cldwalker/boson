require 'boson'

module Boson
  # Defines a RunnerLibrary for use by executables as a simple way to map
  # methods to subcommands
  class Runner < BareRunner
    def self.inherited(mod)
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

      if options[:help]
        if cmd = Command.find(command)
          display_help(command, cmd)
        else
          puts %[Could not find command "#{command}"]
        end
      elsif command.nil?
        display_default_usage
      else
        execute_command(command, args)
      end
    end

    def self.execute_command(cmd, args)
      Command.find(cmd) ? super : no_command_error(cmd)
    end

    def self.display_help(command, cmd)
      usage = cmd.basic_usage.empty? ? '' : " #{cmd.basic_usage}"
      puts "Usage: #{app_name} #{command}#{usage}", "\n"
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
  end
end
