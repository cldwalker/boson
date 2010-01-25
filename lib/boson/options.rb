module Boson
  # This module contains the methods used to define the default option types.
  #
  # === Creating Your Own Option Type
  # Defining your own option type simply requires one method (create_@type) to parse the option value and create
  # the desired object. To create an option type :date, you could create the following create_date method:
  #   # Drop this in your ~/.irbrc after require 'boson'
  #   module Boson::Options::Date
  #     def create_date(value)
  #       # value should be mm/dd
  #       Date.parse(value + "/#{Date.today.year}")
  #     end
  #   end
  #   Boson::OptionParser.send :include, Boson::Options::Date
  #
  # In a FileLibrary, we could then use this new option:
  #   module Calendar
  #     #@options :day=>:date
  #     def appointments(options={})
  #       # ...
  #     end
  #   end
  #   # >> appointments '-d 10/10'   -> {:day=>#<Date: 4910229/2,0,2299161> }
  # As you can see, a date object is created from the :date option's value and passed into appointments().
  #
  # Some additional tips on the create_* method:
  # * The argument passed to the method is the option value from the user.
  # * To access the current option name use @current_option.
  # * To access the hash of attributes the current option has use OptionParser.current_attributes. See
  #   OptionParser.new for more about option attributes.
  #
  # There are two optional methods per option type: validate_@type and usage_for_@type i.e. validate_date and usage_for_date.
  # Like create_@type, validate_@type takes the option's value. If the value validation fails, raise an
  # OptionParser::Error with a proper message. All user-defined option types automatically validate for an option value's existence.
  # The usage_for_* method takes an option's name (i.e. --day) and returns a usage string to be wrapped in '[ ]'. If no usage is defined
  # the default would look like '[--day=:date]'. Consider using the OptionParser.default_usage helper method for your usage.
  module Options
    #:stopdoc:
    # Parse/create methods
    def create_string(value)
      if (values = current_attributes[:values]) && (values = values.sort_by {|e| e.to_s})
        value = auto_alias_value(values, value)
        validate_enum_values(values, value)
      end
      value
    end

    def create_boolean(value)
      if (!@opt_types.key?(dasherize(@current_option)) && @current_option =~ /^no-(\w+)$/)
        opt = (opt = original_no_opt($1)) ? undasherize(opt) : $1
        (@current_option.replace(opt) && false)
      else
        true
      end
    end

    def create_numeric(value)
      value.index('.') ? value.to_f : value.to_i
    end

    def create_array(value)
      splitter = current_attributes[:split] || ','
      array = value.split(splitter)
      if (values = current_attributes[:values]) && (values = values.sort_by {|e| e.to_s })
        if current_attributes[:regexp]
          array = array.map {|e|
            (new_values = values.grep(/#{e}/)).empty? ? e : new_values
          }.compact.flatten.uniq
        else
          array.each {|e| array.delete(e) && array += values if e == '*'}
          array.map! {|e| auto_alias_value(values, e) }
        end
        validate_enum_values(values, array)
      end
      array
    end

    def create_hash(value)
      (keys = current_attributes[:keys]) && keys = keys.sort_by {|e| e.to_s }
      hash = parse_hash(value, keys)
      if keys
        hash = hash.inject({}) {|h,(k,v)|
          h[auto_alias_value(keys, k)] = v; h
        }
        validate_enum_values(keys, hash.keys)
      end
      hash
    end

    def parse_hash(value, keys)
      splitter = current_attributes[:split] || ','
      if !value.include?(':') && current_attributes[:default_keys]
        value = current_attributes[:default_keys].to_s + ":#{value}"
      end

      # Creates array pairs, grouping array of keys with a value
      aoa = Hash[*value.split(/(?::)([^#{Regexp.quote(splitter)}]+)#{Regexp.quote(splitter)}?/)].to_a
      aoa.each_with_index {|(k,v),i| aoa[i][0] = keys.join(splitter) if k == '*' } if keys
      aoa.inject({}) {|t,(k,v)| k.split(splitter).each {|e| t[e] = v }; t }
    end

    # Validation methods
    def validate_string(value)
      raise OptionParser::Error, "cannot pass '#{value}' as an argument to option '#{@current_option}'" if valid?(value)
    end

    def validate_numeric(value)
      unless value =~ OptionParser::NUMERIC and $& == value
        raise OptionParser::Error, "expected numeric value for option '#{@current_option}'; got #{value.inspect}"
      end
    end

    def validate_hash(value)
      if !value.include?(':') && !current_attributes[:default_keys]
        raise(OptionParser::Error, "invalid key:value pair for option '#{@current_option}'")
      end
    end

    # Usage methods
    def usage_for_boolean(opt)
      opt
    end

    def usage_for_string(opt)
      default_usage(opt, undasherize(opt).upcase)
    end

    def usage_for_numeric(opt)
      default_usage opt, "N"
    end

    def usage_for_array(opt)
      default_usage opt, "A,B,C"
    end

    def usage_for_hash(opt)
      default_usage opt, "A:B,C:D"
    end
    #:startdoc:
  end
end
Boson::OptionParser.send :include, Boson::Options
