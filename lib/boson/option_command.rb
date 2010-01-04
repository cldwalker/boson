require 'shellwords'
module Boson
  # A class used by Scientist to wrap around Command objects. It's main purpose is to parse
  # a command's global options (basic options, render options, pipe options) and local options.
  # As the names imply, global options are available to all commands while local options are specific to a command.
  # When passing options to commands, global ones _must_ be passed first, then local ones.
  # For more about pipe and render options see Pipe and View respectively.
  #
  # === Basic Global Options
  # Any command with options comes with basic global options. For example '-hv' on an option command
  # prints a help summarizing global and local options. Another basic global option is --pretend. This
  # option displays what global options have been parsed and the actual arguments to be passed to a
  # command if executed. For example:
  #
  #   # Define this command in a library
  #   options :level=>:numeric, :verbose=>:boolean
  #   def foo(*args)
  #     args
  #   end
  #
  #   irb>> foo 'testin -p -l=1'
  #   Arguments: ["testin", {:level=>1}]
  #   Global options: {:pretend=>true}
  #
  # If a global option conflicts with a local option, the local option takes precedence. You can get around
  # this by passing a --global option which takes a string of options without their dashes. For example:
  #   foo '-p --fields=f1,f2 -l=1'
  #   # is the same as
  #   foo ' -g "p fields=f1,f2" -l=1 '
  #
  # === Toggling Views With the Basic Global Option --render
  # One of the more important global options is --render. This option toggles the rendering of a command's
  # output done with View and Hirb[http://github.com/cldwalker/hirb].
  #
  # Here's a simple example of toggling Hirb's table view:
  #   # Defined in a library file:
  #   #@options {}
  #   def list(options={})
  #     [1,2,3]
  #   end
  #
  #   Using it in irb:
  #   >> list
  #   => [1,2,3]
  #   >> list '-r'  # or list --render
  #   +-------+
  #   | value |
  #   +-------+
  #   | 1     |
  #   | 2     |
  #   | 3     |
  #   +-------+
  #   3 rows in set
  #   => true
  class OptionCommand
    BASIC_OPTIONS = {
      :help=>{:type=>:boolean, :desc=>"Display a command's help"},
      :render=>{:type=>:boolean, :desc=>"Toggle a command's default rendering behavior"},
      :verbose=>{:type=>:boolean, :desc=>"Increase verbosity for help, errors, etc."},
      :global=>{:type=>:string, :desc=>"Pass a string of global options without the dashes"},
      :pretend=>{:type=>:boolean, :desc=>"Display what a command would execute without executing it"},
    } #:nodoc:

    RENDER_OPTIONS = {
      :fields=>{:type=>:array, :desc=>"Displays fields in the order given"},
      :class=>{:type=>:string, :desc=>"Hirb helper class which renders"},
      :max_width=>{:type=>:numeric, :desc=>"Max width of a table"},
      :vertical=>{:type=>:boolean, :desc=>"Display a vertical table"},
    } #:nodoc:

    PIPE_OPTIONS = {
      :sort=>{:type=>:string, :desc=>"Sort by given field"},
      :reverse_sort=>{:type=>:boolean, :desc=>"Reverse a given sort"},
      :query=>{:type=>:hash, :desc=>"Queries fields given field:search pairs"},
    } #:nodoc:

    class <<self
      #:stopdoc:
      def default_option_parser
        @default_option_parser ||= OptionParser.new default_pipe_options.
          merge(default_render_options.merge(BASIC_OPTIONS))
      end

      def default_pipe_options
        @default_pipe_options ||= PIPE_OPTIONS.merge Pipe.pipe_options
      end

      def default_render_options
        @default_render_options ||= RENDER_OPTIONS.merge Boson.repo.config[:render_options] || {}
      end

      def delete_non_render_options(opt)
        opt.delete_if {|k,v| BASIC_OPTIONS.keys.include?(k) }
      end
      #:startdoc:
    end

    attr_accessor :command
    def initialize(cmd)
      @command = cmd
    end

    # Parses arguments and returns global options, local options and leftover arguments.
    def parse(args)
      if args.size == 1 && args[0].is_a?(String)
        global_opt, parsed_options, args = parse_options Shellwords.shellwords(args[0])
      # last string argument interpreted as args + options
      elsif args.size > 1 && args[-1].is_a?(String)
        temp_args = Boson.const_defined?(:BinRunner) ? args : Shellwords.shellwords(args.pop)
        global_opt, parsed_options, new_args = parse_options temp_args
        args += new_args
      # add default options
      elsif @command.options.to_s.empty? || (!@command.has_splat_args? &&
        args.size <= (@command.arg_size - 1).abs) || (@command.has_splat_args? && !args[-1].is_a?(Hash))
          global_opt, parsed_options = parse_options([])[0,2]
      # merge default options with given hash of options
      elsif (@command.has_splat_args? || (args.size == @command.arg_size)) && args[-1].is_a?(Hash)
        global_opt, parsed_options = parse_options([])[0,2]
        parsed_options.merge!(args.pop)
      end
      [global_opt || {}, parsed_options, args]
    end

    #:stopdoc:
    def parse_options(args)
      parsed_options = @command.option_parser.parse(args, :delete_invalid_opts=>true)
      global_options = parse_global_options
      new_args = option_parser.non_opts.dup + @command.option_parser.trailing_non_opts
      [global_options, parsed_options, new_args]
    rescue OptionParser::Error
      global_options = parse_global_options
      global_options[:help] ? [global_options, nil, []] : raise
    end

    def parse_global_options
      global_options = option_parser.parse @command.option_parser.leading_non_opts
      if global_options[:global]
        global_opts = Shellwords.shellwords(global_options[:global]).map {|str|
          ((str[/^(.*?)=/,1] || str).length > 1 ? "--" : "-") + str }
        global_options.merge! option_parser.parse(global_opts)
      end
      global_options
    end

    def option_parser
      @option_parser ||= @command.render_options ? OptionParser.new(all_global_options) :
        self.class.default_option_parser
    end

    def all_global_options
      @command.render_options.each {|k,v|
        if !v.is_a?(Hash) && !v.is_a?(Symbol)
          @command.render_options[k] = {:default=>v}
        end
      }
      render_opts = Util.recursive_hash_merge(@command.render_options, Util.deep_copy(self.class.default_render_options))
      merged_opts = Util.recursive_hash_merge Util.deep_copy(self.class.default_pipe_options), render_opts
      opts = Util.recursive_hash_merge merged_opts, Util.deep_copy(BASIC_OPTIONS)
      set_global_option_defaults opts
    end

    def set_global_option_defaults(opts)
      if !opts[:fields].key?(:values)
        if opts[:fields][:default]
          opts[:fields][:values] = opts[:fields][:default]
        else
          if opts[:change_fields] && (changed = opts[:change_fields][:default])
            opts[:fields][:values] = changed.is_a?(Array) ? changed : changed.values
          end
          opts[:fields][:values] ||= opts[:headers][:default].keys if opts[:headers] && opts[:headers][:default]
        end
        opts[:fields][:enum] = false if opts[:fields][:values] && !opts[:fields].key?(:enum)
      end
      if opts[:fields][:values]
        opts[:sort][:values] ||= opts[:fields][:values]
        opts[:query][:keys] ||= opts[:fields][:values]
        opts[:query][:default_keys] ||= "*"
      end
      opts
    end

    def prepend_default_option(args)
      if @command.default_option && @command.arg_size <= 1 && !@command.has_splat_args? && args[0].to_s[/./] != '-'
        args[0] = "--#{@command.default_option}=#{args[0]}" unless args.join.empty? || args[0].is_a?(Hash)
      end
    end

    def check_argument_size(args)
      if args.size != @command.arg_size && !@command.has_splat_args?
        command_size, args_size = args.size > @command.arg_size ? [@command.arg_size, args.size] :
          [@command.arg_size - 1, args.size - 1]
        raise ArgumentError, "wrong number of arguments (#{args_size} for #{command_size})"
      end
    end

    def add_default_args(args, obj)
      if @command.args && args.size < @command.args.size - 1
        # leave off last arg since its an option
        @command.args.slice(0..-2).each_with_index {|arr,i|
          next if args.size >= i + 1 # only fill in once args run out
          break if arr.size != 2 # a default arg value must exist
          begin
            args[i] = @command.file_parsed_args? ? obj.instance_eval(arr[1]) : arr[1]
          rescue Exception
            raise Scientist::Error, "Unable to set default argument at position #{i+1}.\nReason: #{$!.message}"
          end
        }
      end
    end
    #:startdoc:
  end
end