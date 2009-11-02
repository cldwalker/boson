module Boson
  module Options
    # Parse/create methods
    def create_string(opt)
      value = value_shift
      if (values = current_option_attributes[:values]) && (values = values.sort_by {|e| e.to_s})
        (val = auto_alias_value(values, value)) && value = val
      end
      value
    end

    def create_boolean(opt)
      if (!@opt_types.key?(opt) && @current_option =~ /^no-(\w+)$/)
        opt = (opt = original_no_opt($1)) ? undasherize(opt) : $1
        (@current_option.replace(opt) && false)
      else
        true
      end
    end

    def create_numeric(opt)
      peek.index('.') ? value_shift.to_f : value_shift.to_i
    end

    def create_array(opt)
      splitter = current_option_attributes[:split] || ','
      array = value_shift.split(splitter)
      if (values = current_option_attributes[:values]) && (values = values.sort_by {|e| e.to_s })
        array.each {|e| array.delete(e) && array += values if e == '*'}
        array.each_with_index {|e,i|
          (value = auto_alias_value(values, e)) && array[i] = value
        }
      end
      array
    end

    def create_hash(opt)
      splitter = current_option_attributes[:split] || ','
      (keys = current_option_attributes[:keys]) && keys = keys.sort_by {|e| e.to_s }
      value = value_shift
      if !value.include?(':')
        (defaults = current_option_attributes[:default_keys]) ? value = "#{defaults}:#{value}" :
          raise(OptionParser::Error, "invalid key:value pair for option '#{@current_option}'")
      end
      # Creates array pairs, grouping array of keys with a value
      aoa = Hash[*value.split(/(?::)([^#{Regexp.quote(splitter)}]+)#{Regexp.quote(splitter)}?/)].to_a
      aoa.each_with_index {|(k,v),i| aoa[i][0] = keys.join(splitter) if k == '*' } if keys
      hash = aoa.inject({}) {|t,(k,v)| k.split(splitter).each {|e| t[e] = v }; t }
      keys ? hash.each {|k,v|
              (new_key = auto_alias_value(keys, k)) && hash[new_key] = hash.delete(k)
             } : hash
    end

    # Validation methods
    def validate_string
      raise OptionParser::Error, "cannot pass '#{peek}' as an argument to option '#{@current_option}'" if valid?(peek)
    end

    def validate_numeric
      unless peek =~ OptionParser::NUMERIC and $& == peek
        raise OptionParser::Error, "expected numeric value for option '#{@current_option}'; got #{peek.inspect}"
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
  end
end
Boson::OptionParser.send :include, Boson::Options