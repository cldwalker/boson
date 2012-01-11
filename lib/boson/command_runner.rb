require 'boson'
require 'boson/bin_runner'

module Boson
  class CommandRunner < BinRunner
    def self.inherited(mod)
      Inspector.enable all_classes: true
    end

    def self.init(args)
      Inspector.disable
      Boson::Runner.start args
      Manager.load self
    end

    def self.start(args=ARGV)
      init args
      @command, @options, @args = parse_args(args)

      if @options[:help]
        if (cmd = Boson::Command.find(command))
          puts "Usage: #{app_name} #{command} #{cmd.basic_usage}", "\n"
          if cmd.options
            puts "Options:"
            puts cmd.option_parser.print_usage_table(no_headers: true)
          end
          puts "Description:\n  #{cmd.desc || 'TODO'}"
        else
          puts %[Could not find command "#{command}"]
        end
      elsif @command.nil?
        print_usage
      else
        execute_command(@command, @args)
      end
    end

    def self.autoload_command(cmd)
    end

    def self.print_usage
      puts "Usage: #{app_name} COMMAND ARGS"
    end

    def self.app_name
      File.basename($0).split(' ').first
    end
  end
end
