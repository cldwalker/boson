module Boson
  class Command
    def self.create(name, library)
      new (library.commands_hash[name] || {}).merge({:name=>name, :lib=>library.name})
    end

    def self.create_aliases(commands, lib_module)
      aliases_hash = {}
      select_commands = Boson.commands.select {|e| commands.include?(e.name)}
      select_commands.each do |e|
        if e.alias
          aliases_hash[lib_module.to_s] ||= {}
          aliases_hash[lib_module.to_s][e.name] = e.alias
        end
      end
      generate_aliases(aliases_hash)
    end

    def self.generate_aliases(aliases_hash)
      Alias.manager.create_aliases(:instance_method, aliases_hash)
    end

    def self.find(command, commands=Boson.commands)
      command, subcommand = command.to_s.split('.', 2)
      is_namespace_command = lambda {|current_command|
        [current_command.name, current_command.alias].include?(subcommand) &&
        (namespace_command = commands.find {|f| [f.name, f.alias].include?(command) && f.lib == 'namespace'}) &&
        current_command.lib[/\w+$/] == namespace_command.name
      }

      find_lambda = subcommand ? is_namespace_command : lambda {|e| [e.name, e.alias].include?(command)}
      commands.find(&find_lambda)
    end

    ATTRIBUTES = [:name, :lib, :alias, :description, :options, :args]
    attr_accessor *ATTRIBUTES
    def initialize(hash)
      @name = hash[:name] or raise ArgumentError
      @lib = hash[:lib] or raise ArgumentError
      @alias = hash[:alias] if hash[:alias]
      @description = hash[:description] if hash[:description]
      @options = hash[:options] if hash[:options]
      @args = hash[:args] if hash[:args]
    end

    def library
      @library ||= Boson.library(@lib)
    end

    def args
      @args ||= begin
        if library && File.exists?(library.library_file || '')
          @file_parsed_args = true
          file_string = Boson::FileLibrary.read_library_file(library.library_file)
          ArgumentInspector.arguments_from_file(file_string, @name)
        end
      end
    end

    def file_parsed_args?
      @file_parsed_args
    end

    def option_parser
      @option_parser ||= (@options ? OptionParser.new(@options) : nil)
    end

    def option_help
      @options ? option_parser.to_s : ''
    end

    def has_splat_args?
      @args && @args.any? {|e| e[0][/^\*/] }
    end

    def usage
      return '' if options.nil? && args.nil?
      usage_args = args && @options ? args[0..-2] : args
      str = args ? usage_args.map {|e|
        (e.size < 2) ? "[#{e[0]}]" : "[#{e[0]}=#{@file_parsed_args ? e[1] : e[1].inspect}]"
      }.join(' ') : '[*unknown]'
      str + option_help
    end

    def marshal_dump
      if @args && @args.any? {|e| e[1].is_a?(Module) }
        @args.map! {|e| e.size == 2 ? [e[0], e[1].inspect] : e }
        @file_parsed_args = true
      end
      [@name, @alias, @lib, @description, @options, @args]
    end

    def marshal_load(ary)
      @name, @alias, @lib, @description, @options, @args = ary
    end
  end
end