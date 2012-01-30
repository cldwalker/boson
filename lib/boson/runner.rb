require 'boson'

module Boson
  class Runner < BareRunner
    def self.inherited(mod)
      Inspector.enable all_classes: true, module: mod.singleton_class
    end

    def self.default_libraries
      [self]
    end

    def self.start(args=ARGV)
      super
      init
      command, options, args = parse_args(args)

      if options[:help]
        if (cmd = Boson::Command.find(command))
          display_help(command, cmd)
        else
          puts %[Could not find command "#{command}"]
        end
      elsif command.nil?
        display_usage
      else
        execute_command(command, args)
      end
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

    def self.display_usage
      puts "Usage: #{app_name} COMMAND ARGS"
    end

    def self.app_name
      File.basename($0).split(' ').first
    end
  end
end
