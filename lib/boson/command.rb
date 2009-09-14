require 'shellwords'
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

    attr_accessor :name, :lib, :alias, :description, :options, :args
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
          Inspector.arguments_from_file(file_string, @name)
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

    def create_option_command_block
      command = self
      options = @options.delete(:options) || {}
      default_lambda = lambda {|*args|
        begin
        if args.size == 1 && args[0].is_a?(String)
          args = Shellwords.shellwords(args.join(" "))
          parsed_options = command.option_parser.parse(args, :delete_invalid_opts=>true)
          args = command.option_parser.non_opts
        # last string argument interpreted as args + options
        elsif args.size > 1 && args[-1].is_a?(String)
          parsed_options = command.option_parser.parse(args.pop.split(/\s+/), :delete_invalid_opts=>true)
          args += command.option_parser.non_opts
        # default options
        elsif command.args && args.size == command.args.size - 1
          parsed_options = command.option_parser.parse([], :delete_invalid_opts=>true)
        end
        if parsed_options
          # add in default values from command.args
          if command.args && args.size < command.args.size - 1
            # leave off last arg since its an option
            command.args.slice(0..-2).each_with_index {|arr,i|
              next if args.size >= i + 1 # only fill in once args run out
              break if arr.size != 2 # a default arg value must exist
              begin
                args[i] = command.file_parsed_args? ? Boson.main_object.instance_eval(arr[1]) : arr[1]
              rescue Exception
              end
            }
          end
          args << parsed_options
          if command.args && args.size < command.args.size && !command.has_splat_args?
            raise ArgumentError, "wrong number of arguments (#{args.size} for #{command.args.size})"
          end
        end
        super(*args)
        rescue OptionParser::Error
          $stderr.puts "Error: " + $!.message
        end
      }
    end
  end
end