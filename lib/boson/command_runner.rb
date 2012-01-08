require 'boson'
require 'boson/bin_runner'

module Boson
  class CommandRunner < BinRunner
    def self.inherited(mod)
      Inspector.enable all_classes: true
    end

    def self.start(args=ARGV)
      Inspector.disable
      Boson::Runner.start
      Manager.load self

      @command, @options, @args = parse_args(args)

      if @options[:help]
        puts Boson::Command.usage(@command)
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
