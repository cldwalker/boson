module Boson
  # Scrapes comments right before a method for its attributes. Method attributes must begin with '@' i.e.:
  #    # @desc Does foo
  #    # @options :verbose=>true
  #    def foo(options={})
  #
  # Some rules about these attributes:
  # * Attribute definitions can span multiple lines. When a new attribute starts a line or the comments end,
  #   then a definition ends.
  # * If no @desc is found in the comment block, then the first comment line directly above the method
  #   is assumed to be the value for @desc. This means that no multi-line attribute definitions can occur
  #   without a description since the last line is assumed to be a description.
  # * options, config and render_options attributes can take any valid ruby since they're evaled in their module's context.
  # * desc attribute is not evaled and is simply text to be set as a string.
  #
  # This module was inspired by
  # {pragdave}[http://github.com/pragdavespc/rake/commit/45231ac094854da9f4f2ac93465ed9b9ca67b2da].
  module CommentInspector
    extend self
    EVAL_ATTRIBUTES = [:options, :render_options, :config]

    # Given a method's file string, line number and defining module, returns a hash
    # of attributes defined for that method.
    def scrape(file_string, line, mod, attribute=nil)
      hash = scrape_file(file_string, line) || {}
      options = (arr = hash.delete(:option)) ? parse_option_comments(arr, mod) : {}
      hash.select {|k,v| v && (attribute.nil? || attribute == k) }.each do |k,v|
        hash[k] = EVAL_ATTRIBUTES.include?(k) ? eval_comment(v.join(' '), mod) : v.join(' ')
      end
      (hash[:options] ||= {}).merge!(options) if !options.empty?
      attribute ? hash[attribute] : hash
    end

    #:stopdoc:
    def parse_option_comments(arr, mod)
      arr.inject({}) {|t,e|
        key, val = e.join(' ').split(/\s*,\s*/, 2)
        if val
          key = key.sub(/^\s*:/, '').to_sym
          t[key] = eval_comment(val, mod)
        end
        t
      }
    end

    def eval_comment(value, mod)
      value = "{#{value}}" if !value[/^\s*\{/] && value[/=>/]
      begin mod.module_eval(value); rescue(Exception); nil end
    end

    # Scrapes a given string for commented @keywords, starting with the line above the given line
    def scrape_file(file_string, line)
      lines = file_string.split("\n")
      saved = []
      i = line -2
      while lines[i] =~ /^\s*#\s*(\S+)/ && i >= 0
        saved << lines[i]
        i -= 1
      end

      saved.empty? ? {} : splitter(saved.reverse)
    end

    def splitter(lines)
      hash = {}
      i = 0
      # to magically make the last comment a description
      unless lines.any? {|e| e =~  /^\s*#\s*@desc/ }
        last_line = lines.pop
        hash[:desc] = (last_line =~ /^\s*#\s*([^@\s].*)/) ? [$1] : nil
        lines << last_line unless hash[:desc]
      end

      option = []
      while i < lines.size
        while lines[i] =~ /^\s*#\s*@(\w+)\s*(.*)/
          key = $1.to_sym
          hash[key] = [$2]
          i += 1
          while lines[i] =~ /^\s*#\s*([^@\s].*)/
            hash[key] << $1
            i+= 1
          end
          option << hash.delete(:option) if key == :option
        end
        i += 1
      end
      hash[:option] = option if !option.empty?
      hash
    end
    #:startdoc:
  end
end