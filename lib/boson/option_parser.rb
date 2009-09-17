# This is a modified version of Daniel Berger's Getopt::Long class,
# licensed under Ruby's license.

module Boson
  # Simple Hash with indifferent access
  class IndifferentAccessHash < ::Hash
    def initialize(hash)
      super()
      update hash.each {|k,v| hash[convert_key(k)] = hash.delete(k) }
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

  class OptionParser
    class Error < StandardError; end

    NUMERIC     = /(\d*\.\d+|\d+)/
    LONG_RE     = /^(--\w+[-\w+]*)$/
    SHORT_RE    = /^(-[a-zA-Z])$/i
    EQ_RE       = /^(--\w+[-\w+]*|-[a-zA-Z])=(.*)$/i
    SHORT_SQ_RE = /^-([a-zA-Z]{2,})$/i # Allow either -x -v or -xv style for single char args
    SHORT_NUM   = /^(-[a-zA-Z])#{NUMERIC}$/i
    
    attr_reader :leading_non_opts, :trailing_non_opts, :opt_aliases
    
    def non_opts
      leading_non_opts + trailing_non_opts
    end

    # Takes an array of options. Each array consists of up to three
    # elements that indicate the name and type of option. Returns a hash
    # containing each option name, minus the '-', as a key. The value
    # for each key depends on the type of option and/or the value provided
    # by the user.
    #
    # The long option _must_ be provided. The short option defaults to the
    # first letter of the option. The default type is :boolean.
    #
    # Example:
    #
    #   opts = Boson::OptionParser.new(
    #      "--debug" => true,
    #      ["--verbose", "-v"] => true,
    #      ["--level", "-l"] => :numeric
    #   ).parse(args)
    #
    def initialize(opts)
      @defaults = {}
      # hash of single dash aliases to double dash options
      @opt_aliases = {}
      
      @leading_non_opts, @trailing_non_opts = [], []

      # build hash of dasherized options to option types
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

        if type.is_a?(Hash)
          @option_attributes ||= {}
          @option_attributes[nice_name] = type
          @defaults[nice_name] = type[:default] if type[:default]
          type = determine_option_type(type[:default]) || type[:type] || :boolean
        end

        # allow for aliases as symbols
        (aliases ||= []).map! {|e| e.to_s.index('-') != 0 ? dasherize(e.to_s) : e }
        # if there are no aliases specified, generate one using the first character
        aliases << "-" + nice_name[0,1] if aliases.empty? and nice_name.length > 1
        aliases.each { |e| @opt_aliases[e] = name unless @opt_aliases[e] && @opt_aliases[e] < name }
        
        # set defaults
        case type
          when TrueClass, FalseClass  then  @defaults[nice_name] ||= (type ? true : false)
          when String, Numeric, Array then  @defaults[nice_name] ||= type
        end
        
        mem[name] = determine_option_type(type) || type
        mem
      end

      # remove aliases that happen to coincide with any of the main options
      @opt_aliases.keys.each do |e|
        @opt_aliases.delete(e) if @opt_types.key?(e)
      end
    end

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
        
        option    = normalize_option(option)
        @current_option = undasherize(option)
        type      = option_type(option)

        validate_option_value(type)
        value = get_option_value(type, option)
        # set on different line since current_option may change
        hash[@current_option.to_sym] = value
      end

      @trailing_non_opts = @args
      check_required! hash
      delete_invalid_opts if flags[:delete_invalid_opts]
      hash
    end

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
            when :string then undasherize(opt).gsub(/\-/, "_").upcase
            when :numeric  then "N"
            end
          "[" + opt + "=" + sample.to_s + "]"
        end
      end.join(" ")
    end

    alias :to_s :formatted_usage

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
          array = shift.split(',')
          if values = @option_attributes[@current_option][:values].sort_by {|e| e.to_s } rescue nil
            array.each_with_index {|e,i|
              (value = auto_alias_value(values, e)) && array[i] = value
            }
          end
          array
      end
    end

    def auto_alias_value(values, possible_value)
      values.find {|v| v.to_s =~ /^#{possible_value}/ } or
        raise Error, "Invalid value '#{possible_value}' for option '#{@current_option}'"
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
      [@leading_non_opts, @trailing_non_opts].each do |args|
        args.delete_if {|e|
          invalid = e.to_s[/^-/]
          $stderr.puts "Invalid option '#{e}'" if invalid
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
          raise Error, "no value provided for required option '#{name}'"
        end
      end
    end
  end
end