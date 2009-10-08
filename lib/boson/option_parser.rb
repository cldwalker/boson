module Boson
  # Simple Hash with indifferent access. Used by OptionParser.
  class IndifferentAccessHash < ::Hash
    def initialize(hash)
      super()
      hash.each {|k,v| self[k] = v }
    end

    def [](key)
      super convert_key(key)
    end

    def []=(key, value)
      super convert_key(key), value
    end

    def values_at(*indices)
      indices.collect { |key| self[convert_key(key)] }
    end

    protected
      def convert_key(key)
        key.kind_of?(String) ? key.to_sym : key
      end
  end

  # This class provides option parsing for boolean, string, numeric and array
  # values given a simple hash of options. Setting option values should be straightforward for
  # *nix people. By option type:
  # * *:boolean*: These don't have values i.e. '--debug'. To toogle a boolean, prepend with --no- i.e. '--no-debug'.
  #   Multiple booleans can be joined together i.e. '-d -f -t' == '-dft'.
  # * *:string*: Separate name from value with space or '=' i.e. '--color red' or '--color=red'.
  # * *:numeric*: Receives values as :string does or by appending number right after name i.e.
  #   '-N3' == '-N=3'. 
  # * *:array*: Receives values as :string does. Multiple values are split by ',' i.e.
  #   '--fields 1,2,3' -> ['1','2','3']. The split character can be configured as explained at
  #   OptionParser.new .
  # This is a modified version of Yehuda Katz's Thor::Options class which is a modified version
  # of Daniel Berger's Getopt::Long class (licensed under Ruby's license).
  class OptionParser
    # Raised for all OptionParser errors
    class Error < StandardError; end

    NUMERIC     = /(\d*\.\d+|\d+)/
    LONG_RE     = /^(--\w+[-\w+]*)$/
    SHORT_RE    = /^(-[a-zA-Z])$/i
    EQ_RE       = /^(--\w+[-\w+]*|-[a-zA-Z])=(.*)$/i
    SHORT_SQ_RE = /^-([a-zA-Z]{2,})$/i # Allow either -x -v or -xv style for single char args
    SHORT_NUM   = /^(-[a-zA-Z])#{NUMERIC}$/i
    
    attr_reader :leading_non_opts, :trailing_non_opts, :opt_aliases

    # Array of arguments left after defined options have been parsed out by parse.
    def non_opts
      leading_non_opts + trailing_non_opts
    end

    # Takes a hash of options. Each option, a key-value pair, must provide the option's
    # name and type. Names longer than one character are accessed with '--' while
    # one character names are accessed with '-'. Names can be symbols, strings
    # or even dasherized strings:
    #
    #    Boson::OptionParser.new :debug=>:boolean, 'level'=>:numeric,
    #      '--fields'=>:array
    #
    # Options can have default values and implicit types simply by changing the
    # option type for the default value:
    #
    #    Boson::OptionParser.new :debug=>true, 'level'=>3.1, :fields=>%w{f1 f2}
    #
    # By default every option name longer than one character is given an alias,
    # the first character from its name. For example, the --fields option
    # has -f as its alias. You can override the default alias by providing your own
    # option aliases as an array in the option's key.
    #
    #    Boson::OptionParser.new [:debug, :damnit, :D]=>true
    #
    # Note that aliases are accessed the same way as option names. For the above,
    # --debug, --damnit and -D all refer to the same option.
    #
    # Options can have additional attributes by passing a hash to the option value instead of
    # a type or default:
    # 
    #    Boson::OptionParser.new :fields=>{:type=>:array, :values=>%w{f1 f2 f3},
    #     :enum=>false}
    #
    # Here are the available option attributes:
    #
    # * *:type*: This or :default is required. Available types are :string, :boolean, :array, :numeric.
    # * *:default*: This or :type is required. This is the default value an option has when not passed.
    # * *:values*: An array of values an option can have. Available for :array and :string options.  Values here
    #   can be aliased by typing a unique string it starts with. For example:
    #      
    #     For values foo, odd, optional: f refers to foo, o to odd and op to optional.
    #
    # * *:enum*: Boolean indicating if an option enforces values in :values. Default is true. Available for
    #   :array and :string options.
    # * *:split*: Only for :array options. A string or regular expression on which an array value splits
    #   to produce an array of values. Default is ','.
    def initialize(opts)
      @defaults = {}
      @opt_aliases = {}
      @leading_non_opts, @trailing_non_opts = [], []

      # build hash of dashed options to option types
      # type can be a hash of opt attributes, a default value or a type symbol
      @opt_types = opts.inject({}) do |mem, (name, type)|
        name, *aliases = name if name.is_a?(Array)
        name = name.to_s
        # we need both nice and dasherized form of option name
        if name.index('-') == 0
          nice_name = undasherize name
        else
          nice_name = name
          name = dasherize name
        end
        # store for later
        @opt_aliases[nice_name] = aliases || []

        if type.is_a?(Hash)
          @option_attributes ||= {}
          @option_attributes[nice_name] = type
          @defaults[nice_name] = type[:default] if type[:default]
          @option_attributes[nice_name][:enum] = true if type.key?(:values) && !type.key?(:enum)
          type = determine_option_type(type[:default]) || type[:type] || :boolean
        end

        # set defaults
        case type
          when TrueClass               then  @defaults[nice_name] = true
          when FalseClass              then  @defaults[nice_name] = false
          when String, Numeric, Array  then  @defaults[nice_name] = type
        end
        
        mem[name] = determine_option_type(type) || type
        mem
      end

      # generate hash of dashed aliases to dashed options
      @opt_aliases = @opt_aliases.sort.inject({}) {|h, (nice_name, aliases)|
        name = dasherize nice_name
        # allow for aliases as symbols
        aliases.map! {|e| e.to_s.index('-') != 0 ? dasherize(e.to_s) : e }
        if aliases.empty? and nice_name.length > 1
          opt_alias = nice_name[0,1]
          opt_alias = h.key?("-"+opt_alias) ? "-"+opt_alias.capitalize : "-"+opt_alias
          h[opt_alias] ||= name unless @opt_types.key?(opt_alias)
        else
          aliases.each { |e| h[e] = name unless @opt_types.key?(e) }
        end
        h
      }
    end

    # Parses an array of arguments for defined options to return a hash. Once the parser
    # recognizes a valid option, it continues to parse until an non option argument is detected.
    # Flags that can be passed to the parser:
    # * :opts_before_args: When true options must come before arguments. Default is false.
    # * :delete_invalid_opts: When true deletes any invalid options left after parsing. Default is false.
    def parse(args, flags={})
      @args = args
      # start with defaults
      hash = IndifferentAccessHash.new @defaults
      
      @leading_non_opts = []
      unless flags[:opts_before_args]
        @leading_non_opts << shift until current_is_option? || @args.empty?
      end

      while current_is_option?
        case shift
        when SHORT_SQ_RE
          unshift $1.split('').map { |f| "-#{f}" }
          next
        when EQ_RE, SHORT_NUM
          unshift $2
          option = $1
        when LONG_RE, SHORT_RE
          option = $1
        end
        
        dashed_option = normalize_option(option)
        @current_option = undasherize(dashed_option)
        type = option_type(dashed_option)
        validate_option_value(type)
        value = get_option_value(type, dashed_option)
        # set on different line since current_option may change
        hash[@current_option.to_sym] = value
      end

      @trailing_non_opts = @args
      check_required! hash
      delete_invalid_opts if flags[:delete_invalid_opts]
      hash
    end

    # One-line option usage
    def formatted_usage
      return "" if @opt_types.empty?
      @opt_types.map do |opt, type|
        case type
        when :boolean
          "[#{opt}]"
        when :required
          opt + "=" + opt.gsub(/\-/, "").upcase
        else
          sample = @defaults[undasherize(opt)]
          sample ||= case type
            when :string  then undasherize(opt).gsub(/\-/, "_").upcase
            when :numeric then "N"
            when :array   then "A,B,C"
            end
          "[" + opt + "=" + sample.to_s + "]"
        end
      end.join(" ")
    end

    alias :to_s :formatted_usage

    # More verbose option help in the form of a table.
    def print_usage_table(render_options={})
      aliases = @opt_aliases.invert
      additional = [:desc, :values].select {|e| (@option_attributes || {}).values.any? {|f| f.key?(e) } }
      opts = @opt_types.keys.sort.inject([]) {|t,e|
        h = {:name=>e, :aliases=>aliases[e], :type=>@opt_types[e]}
        additional.each {|f| h[f] = (@option_attributes[undasherize(e)] || {})[f]  }
        t << h
      }
      render_options = {:headers=>{:name=>"Option", :aliases=>"Alias", :desc=>'Description', :values=>'Values'},
        :fields=>[:name, :aliases, :type] + additional, :description=>false, :filters=>{:values=>lambda {|e| (e || []).join(',')} }
      }.merge(render_options)
      View.render opts, render_options
    end

    private
    def determine_option_type(value)
      case value
        when TrueClass, FalseClass then :boolean
        when String                then :string
        when Numeric               then :numeric
        when Array                 then :array
        else nil
      end
    end

    def get_option_value(type, opt)
      case type
        when :required
          shift
        when :string
          value = shift
          if (values = @option_attributes[@current_option][:values].sort_by {|e| e.to_s} rescue nil)
            (val = auto_alias_value(values, value)) && value = val
          end
          value
        when :boolean
          (!@opt_types.key?(opt) && @current_option =~ /^no-(\w+)$/) ? (@current_option.replace($1) && false) : true
        when :numeric
          peek.index('.') ? shift.to_f : shift.to_i
        when :array
          splitter = (@option_attributes[@current_option][:split] rescue nil) || ','
          array = shift.split(splitter)
          if values = @option_attributes[@current_option][:values].sort_by {|e| e.to_s } rescue nil
            array.each_with_index {|e,i|
              (value = auto_alias_value(values, e)) && array[i] = value
            }
          end
          array
      end
    end

    def auto_alias_value(values, possible_value)
      values.find {|v| v.to_s =~ /^#{possible_value}/ } or (@option_attributes[@current_option][:enum] ?
        raise(Error, "invalid value '#{possible_value}' for option '#{@current_option}'") : possible_value)
    end

    def validate_option_value(type)
      if type != :boolean && peek.nil?
        raise Error, "no value provided for option '#{@current_option}'"
      end

      case type
      when :required, :string
        raise Error, "cannot pass '#{peek}' as an argument to option '#{@current_option}'" if valid?(peek)
      when :numeric
        unless peek =~ NUMERIC and $& == peek
          raise Error, "expected numeric value for option '#{@current_option}'; got #{peek.inspect}"
        end
      end
    end

    def delete_invalid_opts
      [@trailing_non_opts].each do |args|
        args.delete_if {|e|
          invalid = e.to_s[/^-/]
          $stderr.puts "Deleted invalid option '#{e}'" if invalid
          invalid
        }
      end
    end

    def undasherize(str)
      str.sub(/^-{1,2}/, '')
    end
    
    def dasherize(str)
      (str.length > 1 ? "--" : "-") + str
    end
    
    def peek
      @args.first
    end

    def shift
      @args.shift
    end

    def unshift(arg)
      unless arg.kind_of?(Array)
        @args.unshift(arg)
      else
        @args = arg + @args
      end
    end
    
    def valid?(arg)
      if arg.to_s =~ /^--no-(\w+)$/
        @opt_types.key?(arg) or (@opt_types["--#{$1}"] == :boolean)
      else
        @opt_types.key?(arg) or @opt_aliases.key?(arg)
      end
    end

    def current_is_option?
      case peek
      when LONG_RE, SHORT_RE, EQ_RE, SHORT_NUM
        valid?($1)
      when SHORT_SQ_RE
        $1.split('').any? { |f| valid?("-#{f}") }
      end
    end
    
    def normalize_option(opt)
      @opt_aliases.key?(opt) ? @opt_aliases[opt] : opt
    end
    
    def option_type(opt)
      if opt =~ /^--no-(\w+)$/
        @opt_types[opt] || @opt_types["--#{$1}"]
      else
        @opt_types[opt]
      end
    end
    
    def check_required!(hash)
      for name, type in @opt_types
        if type == :required and !hash[undasherize(name)]
          raise Error, "no value provided for required option '#{undasherize(name)}'"
        end
      end
    end
  end
end
