module Boson
  # This class concisely defines commandline options that when parsed produce a
  # Hash of option keys and values.
  # Additional points:
  # * Setting option values should follow conventions in *nix environments.
  #   See examples below.
  # * By default, there are 5 option types, each which produce different
  #   objects for option values.
  # * The default option types can produce objects for one or more of the following
  #   Ruby classes:  String, Integer, Float, Array, Hash, FalseClass, TrueClass.
  # * Users can define their own option types which create objects for _any_
  #   Ruby class. See Options.
  # * Each option type can have attributes to enable more features (see
  #   OptionParser.new).
  # * When options are parsed by parse(), an indifferent access hash is returned.
  # * Options are also called switches, parameters, flags etc.
  # * Option parsing stops when it comes across a '--'.
  #
  # Default option types:
  # [*:boolean*] This option has no passed value. To toogle a boolean, prepend
  #              with '--no-'. Multiple booleans can be joined together.
  #                '--debug'    -> {:debug=>true}
  #                '--no-debug' -> {:debug=>false}
  #                '--no-d'     -> {:debug=>false}
  #                '-d -f -t' same as '-dft'
  # [*:string*] Sets values by separating name from value with space or '='.
  #               '--color red' -> {:color=>'red'}
  #               '--color=red' -> {:color=>'red'}
  #               '--color "gotta love spaces"' -> {:color=>'gotta love spaces'}
  # [*:numeric*] Sets values as :string does or by appending number right after
  #              aliased name. Shortened form can be appended to joined booleans.
  #                '-n3'  -> {:num=>3}
  #                '-dn3' -> {:debug=>true, :num=>3}
  # [*:array*] Sets values as :string does. Multiple values are split by a
  #            configurable character Default is ',' (see OptionParser.new).
  #            Passing '*' refers to all known :values.
  #              '--fields 1,2,3' -> {:fields=>['1','2','3']}
  #              '--fields *'     -> {:fields=>['1','2','3']}
  # [*:hash*] Sets values as :string does. Key-value pairs are split by ':' and
  #           pairs are split by a configurable character (default ',').
  #           Multiple keys can be joined to one value. Passing '*' as a key
  #           refers to all known :keys.
  #             '--fields a:b,c:d' -> {:fields=>{'a'=>'b', 'c'=>'d'} }
  #             '--fields a,b:d'   -> {:fields=>{'a'=>'d', 'b'=>'d'} }
  #             '--fields *:d'     -> {:fields=>{'a'=>'d', 'b'=>'d', 'c'=>'d'} }
  #
  # This is a modified version of Yehuda Katz's Thor::Options class which is a
  # modified version of Daniel Berger's Getopt::Long class (Ruby license).
  class OptionParser
    # Raised for all OptionParser errors
    class Error < StandardError; end

    NUMERIC     = /(\d*\.\d+|\d+)/
    LONG_RE     = /^(--\w+[-\w+]*)$/
    SHORT_RE    = /^(-[a-zA-Z])$/i
    EQ_RE       = /^(--\w+[-\w+]*|-[a-zA-Z])=(.*)$/i
    # Allow either -x -v or -xv style for single char args
    SHORT_SQ_RE = /^-([a-zA-Z]{2,})$/i
    SHORT_NUM   = /^(-[a-zA-Z])#{NUMERIC}$/i
    STOP_STRINGS = %w{-- -}

    attr_reader :leading_non_opts, :trailing_non_opts, :opt_aliases

    # Array of arguments left after defined options have been parsed out by parse.
    def non_opts
      leading_non_opts + trailing_non_opts
    end

    # Takes a hash of options. Each option, a key-value pair, must provide the
    # option's name and type. Names longer than one character are accessed with
    # '--' while one character names are accessed with '-'. Names can be
    # symbols, strings or even dasherized strings:
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
    # the first character from its name. For example, the --fields option has -f
    # as its alias. You can override the default alias by providing your own
    # option aliases as an array in the option's key.
    #
    #    Boson::OptionParser.new [:debug, :damnit, :D]=>true
    #
    # Note that aliases are accessed the same way as option names. For the
    # above, --debug, --damnit and -D all refer to the same option.
    #
    # Options can have additional attributes by passing a hash to the option
    # value instead of a type or default:
    #
    #    Boson::OptionParser.new :fields=>{:type=>:array, :values=>%w{f1 f2 f3},
    #     :enum=>false}
    #
    # These attributes are available when an option is parsed via
    # current_attributes().  Here are the available option attributes for the
    # default option types:
    #
    # [*:type*] This or :default is required. Available types are :string,
    #           :boolean, :array, :numeric, :hash.
    # [*:default*] This or :type is required. This is the default value an
    #              option has when not passed.
    # [*:bool_default*] This is the value an option has when passed as a
    #                   boolean. However, by enabling this an option can only
    #                   have explicit values with '=' i.e. '--index=alias' and
    #                   no '--index alias'. If this value is a string, it is
    #                   parsed as any option value would be. Otherwise, the
    #                   value is passed directly without parsing.
    # [*:required*] Boolean indicating if option is required. Option parses
    #               raises error if value not given. Default is false.
    # [*:alias*] Alternative way to define option aliases with an option name
    #            or an array of them. Useful in yaml files. Setting to false
    #            will prevent creating an automatic alias.
    # [*:values*] An array of values an option can have. Available for :array
    #             and :string options. Values here can be aliased by typing a
    #             unique string it starts with or underscore aliasing (see
    #             Util.underscore_search). For example, for values foo, odd and
    #             obnoxiously_long, f refers to foo, od to odd and o_l to
    #             obnoxiously_long.
    # [*:enum*] Boolean indicating if an option enforces values in :values or
    #           :keys. Default is true. For :array, :hash and :string options.
    # [*:split*] For :array and :hash options. A string or regular expression
    #            on which an array value splits to produce an array of values.
    #            Default is ','.
    # [*:keys*] :hash option only. An array of values a hash option's keys can
    #            have. Keys can be aliased just like :values.
    # [*:default_keys*] For :hash option only. Default keys to assume when only
    #                   a value is given. Multiple keys can be joined by the
    #                   :split character. Defaults to first key of :keys if
    #                   :keys given.
    # [*:regexp*] For :array option with a :values attribute. Boolean indicating
    #             that each option value does a regular expression search of
    #             :values. If there are values that match, they replace the
    #             original option value. If none, then the original option
    #             value is used.
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
          @opt_aliases[nice_name] = Array(type[:alias]) if type.key?(:alias)
          @defaults[nice_name] = type[:default] if type[:default]
          if (type.key?(:values) || type.key?(:keys)) && !type.key?(:enum)
            @option_attributes[nice_name][:enum] = true
          end
          if type.key?(:keys)
            @option_attributes[nice_name][:default_keys] ||= type[:keys][0]
          end
          type = type[:type] || (!type[:default].nil? ?
            determine_option_type(type[:default]) : :boolean)
        end

        # set defaults
        case type
        when TrueClass                     then  @defaults[nice_name] = true
        when FalseClass                    then  @defaults[nice_name] = false
        else @defaults[nice_name] = type unless type.is_a?(Symbol)
        end
        mem[name] = !type.nil? ? determine_option_type(type) : type
        mem
      end

      # generate hash of dashed aliases to dashed options
      @opt_aliases = @opt_aliases.sort.inject({}) {|h, (nice_name, aliases)|
        name = dasherize nice_name
        # allow for aliases as symbols
        aliases.map! {|e|
          e.to_s.index('-') == 0 || e == false ? e : dasherize(e.to_s) }

        if aliases.empty? and nice_name.length > 1
          opt_alias = nice_name[0,1]
          opt_alias = h.key?("-"+opt_alias) ? "-"+opt_alias.capitalize :
            "-"+opt_alias
          h[opt_alias] ||= name unless @opt_types.key?(opt_alias)
        else
          aliases.each {|e| h[e] = name if !@opt_types.key?(e) && e != false }
        end
        h
      }
    end

    # Parses an array of arguments for defined options to return an indifferent
    # access hash. Once the parser recognizes a valid option, it continues to
    # parse until an non option argument is detected.
    # @param [Hash] flags
    # @option flags [Boolean] :opts_before_args When true options must come
    #   before arguments. Default is false.
    # @option flags [Boolean] :delete_invalid_opts When true deletes any
    #   invalid options left after parsing. Will stop deleting if it comes
    #   across - or --. Default is false.
    def parse(args, flags={})
      @args = args
      # start with symbolized defaults
      hash = Hash[@defaults.map {|k,v| [k.to_sym, v] }]

      @leading_non_opts = []
      unless flags[:opts_before_args]
        @leading_non_opts << shift until current_is_option? || @args.empty? ||
          STOP_STRINGS.include?(peek)
      end

      while current_is_option?
        case @original_current_option = shift
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
        value = create_option_value(type)
        # set on different line since current_option may change
        hash[@current_option.to_sym] = value
      end

      @trailing_non_opts = @args
      check_required! hash
      delete_invalid_opts if flags[:delete_invalid_opts]
      indifferent_hash.tap {|h| h.update hash }
    end

    # Helper method to generate usage. Takes a dashed option and a string value
    # indicating an option value's format.
    def default_usage(opt, val)
      opt + "=" + (@defaults[undasherize(opt)] || val).to_s
    end

    # Generates one-line usage of all options.
    def formatted_usage
      return "" if @opt_types.empty?
      @opt_types.map do |opt, type|
        val = respond_to?("usage_for_#{type}", true) ?
          send("usage_for_#{type}", opt) : "#{opt}=:#{type}"
        "[" + val + "]"
      end.join(" ")
    end

    alias :to_s :formatted_usage

    # More verbose option help in the form of a table.
    def print_usage_table(options={})
      fields = get_usage_fields options[:fields]
      fields, opts =  get_fields_and_options(fields, options)
      render_table(fields, opts, options)
    end

    module API
      def get_fields_and_options(fields, options)
        opts = all_options_with_fields fields
        [fields, opts]
      end

      def render_table(fields, arr, options)
        headers = options[:no_headers] ? [] : [['Name', 'Desc'], ['----', '----']]
        arr_of_arr = headers + arr.map do |row|
          [ row.values_at(:alias, :name).compact.join(', '), row[:desc].to_s ]
        end
        puts Util.format_table(arr_of_arr)
      end
    end
    include API

    # Hash of option names mapped to hash of its external attributes
    def option_attributes
      @option_attributes || {}
    end

    # Hash of option attributes for the currently parsed option. _Any_ hash keys
    # passed to an option are available here. This means that an option type can
    # have any user-defined attributes available during option parsing and
    # object creation.
    def current_attributes
      @option_attributes && @option_attributes[@current_option] || {}
    end

    # Removes dashes from a dashed option i.e. '--date' -> 'date' and '-d' -> 'd'.
    def undasherize(str)
      str.sub(/^-{1,2}/, '')
    end

    # Adds dashes to an option name i.e. 'date' -> '--date' and 'd' -> '-d'.
    def dasherize(str)
      (str.length > 1 ? "--" : "-") + str
    end

    # List of option types
    def types
      @opt_types.values
    end

    # List of option names
    def names
      @opt_types.keys.map {|e| undasherize e }
    end

    # List of option aliases
    def aliases
      @opt_aliases.keys.map {|e| undasherize e }
    end

    # Creates a Hash with indifferent access
    def indifferent_hash
      Hash.new {|hash,key| hash[key.to_sym] if String === key }
    end

    def delete_leading_invalid_opts
      delete_invalid_opts @leading_non_opts
    end

    private
    def all_options_with_fields(fields)
      aliases = @opt_aliases.invert
      @opt_types.keys.sort.inject([]) {|t,e|
        nice_name = undasherize(e)
        h = {:name=>e, :type=>@opt_types[e], :alias=>aliases[e] || nil }
        h[:default] = @defaults[nice_name] if fields.include?(:default)
        (fields - h.keys).each {|f|
          h[f] = (option_attributes[nice_name] || {})[f]
        }
        t << h
      }
    end

    def get_usage_fields(fields)
      fields || ([:name, :alias, :type] + [:desc, :values, :keys].select {|e|
        option_attributes.values.any? {|f| f.key?(e) } }).uniq
    end

    def option_type(opt)
      if opt =~ /^--no-(\w+)$/
        @opt_types[opt] || @opt_types[dasherize($1)] ||
          @opt_types[original_no_opt($1)]
      else
        @opt_types[opt]
      end
    end

    def determine_option_type(value)
      return value if value.is_a?(Symbol)
      case value
      when TrueClass, FalseClass   then :boolean
      when Numeric                 then :numeric
      else Util.underscore(value.class.to_s).to_sym
      end
    end

    def value_shift
      return shift if !current_attributes.key?(:bool_default)
      return shift if @original_current_option =~ EQ_RE
      current_attributes[:bool_default]
    end

    def create_option_value(type)
      if current_attributes.key?(:bool_default) &&
        (@original_current_option !~ EQ_RE) &&
        !(bool_default = current_attributes[:bool_default]).is_a?(String)
          bool_default
      else
        respond_to?("create_#{type}", true) ?
          send("create_#{type}", type != :boolean ? value_shift : nil) :
          raise(Error, "Option '#{@current_option}' is invalid option type " +
            "#{type.inspect}.")
      end
    end

    def auto_alias_value(values, possible_value)
      if Boson.config[:option_underscore_search]
        self.class.send(:define_method, :auto_alias_value) {|values, possible_val|
          Util.underscore_search(possible_val, values, true) || possible_val
        }
      else
        self.class.send(:define_method, :auto_alias_value) {|values, possible_val|
          values.find {|v| v.to_s =~ /^#{possible_val}/ } || possible_val
        }
      end
      auto_alias_value(values, possible_value)
    end

    def validate_enum_values(values, possible_values)
      if current_attributes[:enum]
        Array(possible_values).each {|e|
          if !values.include?(e)
            raise(Error, "invalid value '#{e}' for option '#{@current_option}'")
          end
        }
      end
    end

    def validate_option_value(type)
      return if current_attributes.key?(:bool_default)
      if type != :boolean && peek.nil?
        raise Error, "no value provided for option '#{@current_option}'"
      end
      send("validate_#{type}", peek) if respond_to?("validate_#{type}", true)
    end

    def delete_invalid_opts(arr=@trailing_non_opts)
      stop = nil
      arr.delete_if do |e|
        stop ||= STOP_STRINGS.include?(e)
        invalid = e.start_with?('-') && !stop
        warn "Deleted invalid option '#{e}'" if invalid
        invalid
      end
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
        @opt_types.key?(arg) or (@opt_types[dasherize($1)] == :boolean) or
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

    def original_no_opt(opt)
      @opt_aliases[dasherize(opt)]
    end

    def check_required!(hash)
      for name, type in @opt_types
        @current_option = undasherize(name)
        if current_attributes[:required] && !hash.key?(@current_option.to_sym)
          raise Error, "no value provided for required option '#{@current_option}'"
        end
      end
    end
  end
end
