module Boson
  # Scrapes a method's comments for metadata.
  # Inspired by http://github.com/pragdavespc/rake/commit/45231ac094854da9f4f2ac93465ed9b9ca67b2da
  module CommentInspector
    extend self
    EVAL_ATTRIBUTES = [:options, :render_options]

    def scrape(file_string, line, mod, attribute=nil)
      hash = scrape_file(file_string, line) || {}
      hash.select {|k,v| v && (attribute.nil? || attribute == k) }.each do |k,v|
        hash[k] = EVAL_ATTRIBUTES.include?(k) ? eval_comment(v.join(' '), mod) : v.join(' ')
      end
      attribute ? hash[attribute] : hash
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

      while i < lines.size
        while lines[i] =~ /^\s*#\s*@(\w+)\s*(.*)/
          key = $1.to_sym
          hash[key] = [$2]
          i += 1
          while lines[i] =~ /^\s*#\s*([^@\s].*)/
            hash[key] << $1
            i+= 1
          end
        end
        i += 1
      end
      hash
    end
  end
end