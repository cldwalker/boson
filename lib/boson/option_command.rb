module Boson
  class OptionCommand
    GLOBAL_OPTIONS = {
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
      :sort=>{:type=>:string, :desc=>"Sort by given field"},
      :reverse_sort=>{:type=>:boolean, :desc=>"Reverse a given sort"},
      :query=>{:type=>:hash, :desc=>"Queries fields given field:search pairs"},
    } #:nodoc:

    class <<self
      def default_option_parser
        @default_option_parser ||= OptionParser.new default_render_options.merge(default_global_options)
      end

      def default_global_options
        @default_global_options ||= GLOBAL_OPTIONS.merge Boson.repo.config[:global_options] || {}
      end

      def default_render_options
        @default_render_options ||= RENDER_OPTIONS.merge Boson.repo.config[:render_options] || {}
      end
    end

    attr_accessor :command
    def initialize(cmd)
      @command = cmd
    end

    # choose current parser
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
      opts = Util.recursive_hash_merge render_opts, Util.deep_copy(self.class.default_global_options)
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
  end
end