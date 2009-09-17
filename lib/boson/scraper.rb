module Boson
  module Scraper
    extend self
    # Scrapes a given string for commented @keywords, starting with the line above the given line
    def scrape(file_string, line)
      (lines = scraper(file_string, line)) ? splitter(lines) : {}
    end

    def splitter(lines)
      hash = {}
      i = 0
      # to give us a magic
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