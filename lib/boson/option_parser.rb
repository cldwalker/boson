module Boson
  # Simple Hash with indifferent access and retrieval of keys. Other actions such as merging should assume
  # symbolic keys. Used by OptionParser.
  class IndifferentAccessHash < ::Hash
    #:stopdoc:
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
    #:startdoc:
  end

  # This class concisely defines commandline options that can be parsed produce a Hash. Additional points:
  # * Setting option values should follow conventions in *nix environments.
  # * Any option type can be passed as a boolean if it has a :bool_default attribute.
  # * When options are parsed by OptionParser.parse, an IndifferentAccessHash hash is returned.
  # * Each value in the returned options hash can be any of the following Ruby objects: String, Integer, Float,
  #   Array, Hash, FalseClass, TrueClass.
  # * Each option can have option attributes to enable more features (see OptionParser.new).
  # * Options are also called switches, parameters, flags etc.
  #
  # Available option types:
  # [*:boolean*] This option has no passed value. To toogle a boolean, prepend with '--no-'.
  #              Multiple booleans can be joined together.
  #                '--debug'    -> {:debug=>true}
  #                '--no-debug' -> {:debug=>false}
  #                '--no-d'     -> {:debug=>false}
  #                '-d -f -t' same as '-dft'
  # [*:string*] Sets values by separating name from value with space or '='.
  #               '--color red' -> {:color=>'red'}
  #               '--color=red' -> {:color=>'red'}
  #               '--color "gotta love spaces"' -> {:color=>'gotta love spaces'}
  # [*:numeric*] Sets values as :string does or by appending number right after aliased name. Shortened form
  #              can be appended to joined booleans.
  #                '-n3'  -> {:num=>3}
  #                '-dn3' -> {:debug=>true, :num=>3}
  # [*:array*] Sets values as :string does. Multiple values are split by a configurable character
  #            (default ','). See OptionParser.new for more.
  #             '--fields 1,2,3' -> {:fields=>['1','2','3']}
  # [*:hash*] Sets values as :string does. Key-value pairs are split by ':' and pairs are split by
  #           a configurable character (default ','). Multiple keys can be joined to one value. Passing '*'
  #           as a key refers to all known :keys.
  #             '--fields a:b,c:d' -> {:fields=>{'a'=>'b', 'c'=>'d'} }
  #             '--fields a,b:d'   -> {:fields=>{'a'=>'d', 'b'=>'d'} }
  #             '--fields *:d'     -> {:fields=>{'a'=>'d', 'b'=>'d', 'c'=>'d'} }
  #
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
    # Here are the available option attributes (some are specific to option types):
    #
    # [*:type*] This or :default is required. Available types are :string, :boolean, :array, :numeric, :hash.
    # [*:default*] This or :type is required. This is the default value an option has when not passed.
    # [*:bool_default*] This is the default value an option has when passed as a boolean.
    # [*:required*] Boolean indicating if option is required. Option parses raises error if value not given.
    #               Default is false.
    # [*:values*] An array of values an option can have. Available for :array and :string options.  Values here
    #             can be aliased by typing a unique string it starts with. For example, for values foo, odd, optional,
    #             f refers to foo, o to odd and op to optional.
    # [*:enum*] Boolean indicating if an option enforces values in :values or :keys. Default is true. For
    #           :array, :hash and :string options.
    # [*:split*] For :array and :hash options. A string or regular expression on which an array value splits
    #            to produce an array of values. Default is ','.
    # [*:keys*] :hash option only. An array of values a hash option's keys can have. Keys can be aliased just like :values.
    # [:default_keys] :hash option only. Default keys to assume when only a value is given. Multiple keys can be joined
    #                 by the :split character. Defaults to first key of :keys if :keys given.
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
          @option_attributes[nice_name][:enum] = true if (type.key?(:values) || type.key?(:keys)) &&
            !type.key?(:enum)
          @option_attributes[nice_name][:default_keys] ||= type[:keys][0] if type.key?(:keys)
          type = determine_option_type(type[:default]) || type[:type] || :boolean
        end

        # set defaults
        case type
          when TrueClass                     then  @defaults[nice_name] = true
          when FalseClass                    then  @defaults[nice_name] = false
          when String, Numeric, Array, Hash  then  @defaults[nice_name] = type
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

    # Parses an array of arguments for defined options to return an IndifferentAccessHash. Once the parser
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
        else
          sample = @defaults[undasherize(opt)]
          sample ||= case type
            when :string  then undasherize(opt).gsub(/\-/, "_").upcase
            when :numeric then "N"
            when :array   then "A,B,C"
            when :hash    then "A:B,C:D"
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
      render_options = {:headers=>{:name=>"Option", :aliases=>"Alias", :desc=>'Description', :values=>'Values', :type=>'Type'},
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
        when Hash                  then :hash
        else nil
      end
    end

    def value_shift
      return shift if !(bool_default = current_option_attributes[:bool_default])
      return shift if peek && !valid?(peek)
      bool_default
    end

    def get_option_value(type, opt)
      case type
        when :string
          value = value_shift
          if (values = current_option_attributes[:values]) && (values = values.sort_by {|e| e.to_s})
            (val = auto_alias_value(values, value)) && value = val
          end
          value
        when :boolean
          if (!@opt_types.key?(opt) && @current_option =~ /^no-(\w+)$/)
            opt = (opt = original_no_opt($1)) ? undasherize(opt) : $1
            (@current_option.replace(opt) && false)
          else
            true
          end
        when :numeric
          peek.index('.') ? value_shift.to_f : value_shift.to_i
        when :array
          splitter = current_option_attributes[:split] || ','
          array = value_shift.split(splitter)
          if (values = current_option_attributes[:values]) && (values = values.sort_by {|e| e.to_s })
            array.each_with_index {|e,i|
              (value = auto_alias_value(values, e)) && array[i] = value
            }
          end
          array
        when :hash
          splitter = current_option_attributes[:split] || ','
          (keys = current_option_attributes[:keys]) && keys = keys.sort_by {|e| e.to_s }
          # Creates array pairs, grouping array of keys with a value
          value = value_shift
          if !value.include?(':')
            (defaults = current_option_attributes[:default_keys]) ? value = "#{defaults}:#{value}" :
              raise(Error, "invalid key:value pair for option '#{@current_option}'")
          end
          aoa = Hash[*value.split(/(?::)([^#{Regexp.quote(splitter)}]+)#{Regexp.quote(splitter)}?/)].to_a
          aoa.each_with_index {|(k,v),i| aoa[i][0] = keys.join(splitter) if k == '*' } if keys
          hash = aoa.inject({}) {|t,(k,v)| k.split(splitter).each {|e| t[e] = v }; t }
          keys ? hash.each {|k,v|
                  (new_key = auto_alias_value(keys, k)) && hash[new_key] = hash.delete(k)
                 } : hash
      end
    end

    def current_option_attributes
      @option_attributes && @option_attributes[@current_option] || {}
    end

    def auto_alias_value(values, possible_value)
      values.find {|v| v.to_s =~ /^#{possible_value}/ } or (@option_attributes[@current_option][:enum] ?
        raise(Error, "invalid value '#{possible_value}' for option '#{@current_option}'") : possible_value)
    end

    def validate_option_value(type)
      return if current_option_attributes[:bool_default]
      if type != :boolean && peek.nil?
        raise Error, "no value provided for option '#{@current_option}'"
      end

      case type
      when :string
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
        @opt_types.key?(arg) or (@opt_types["--#{$1}"] == :boolean) or
          (@opt_types[original_no_opt($1)] == :boolean)
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
        @opt_types[opt] || @opt_types["--#{$1}"] || @opt_types[original_no_opt($1)]
      else
        @opt_types[opt]
      end
    end

    def original_no_opt(opt)
      @opt_aliases[dasherize(opt)]
    end

    def check_required!(hash)
      for name, type in @opt_types
        @current_option = undasherize(name)
        if current_option_attributes[:required] && !hash.key?(@current_option.to_sym)
          raise Error, "no value provided for required option '#{@current_option}'"
        end
      end
    end
  end
end
