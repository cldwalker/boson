module Boson
  # Scrapes a method's comments for metadata.
  # Inspired by http://github.com/pragdavespc/rake/commit/45231ac094854da9f4f2ac93465ed9b9ca67b2da
  module CommentInspector
    extend self

    def description_from_file(file_string, line)
      (hash = scrape(file_string, line))[:desc] && hash[:desc].join(" ")
    end

    def options_from_file(file_string, line, mod=nil)
      if (hash = scrape(file_string, line)).key?(:options)
        options = hash[:options].join(" ")
        if mod
          options = "{#{options}}" if !options[/^\s*\{/] && options[/=>/]
          begin mod.module_eval(options); rescue(Exception); nil end
        else
          !!options
        end
      end
    end

    # Scrapes a given string for commented @keywords, starting with the line above the given line
    def scrape(file_string, line)
      (lines = scraper(file_string, line)) ? splitter(lines) : {}
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

    def scraper(file_string, line)
      lines = file_string.split("\n")
      saved = []
      i = line -2
      while lines[i] =~ /^\s*#\s*(\S+)/ && i >= 0
        saved << lines[i]
        i -= 1
      end
      saved.empty? ? nil : saved.reverse
    end
  end
end