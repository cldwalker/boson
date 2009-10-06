module Boson
  # Scrapes and processes method metadata with the inspectors (MethodInspector, CommentInspector
  # and ArgumentInspector) and hands off the usable data to FileLibrary objects.
  module Inspector
    extend self
    attr_reader :enabled

    # Enable scraping by overridding method_added to snoop on a library while it's
    # loading its methods.
    def enable
      @enabled = true
      body = MethodInspector::METHODS.map {|e|
        %[def #{e}(val)
            Boson::MethodInspector.#{e}(self, val)
          end]
      }.join("\n") +
      %[
        def new_method_added(method)
          Boson::MethodInspector.new_method_added(self, method)
        end

        alias_method :_old_method_added, :method_added
        alias_method :method_added, :new_method_added
      ]
    ::Module.module_eval body
    end

    # Disable scraping method data.
    def disable
      ::Module.module_eval %[
        Boson::MethodInspector::METHODS.each {|e| remove_method e }
        alias_method :method_added, :_old_method_added
      ]
      @enabled = false
    end

    # Adds method data scraped for the library's module to the library's commands.
    def add_method_data_to_library(library)
      @commands_hash = library.commands_hash
      @library_file = library.library_file
      MethodInspector.current_module = library.module
      @store = MethodInspector.store
      add_method_scraped_data
      add_comment_scraped_data
    end

    #:stopdoc:
    def add_method_scraped_data
      (MethodInspector::METHODS + [:method_args]).each do |e|
        key = command_key(e)
        (@store[e] || []).each do |cmd, val|
          if no_command_config_for(cmd, key)
            (@commands_hash[cmd] ||= {})[key] = val
          end
        end
      end
    end

    def add_comment_scraped_data
      (@store[:method_locations] || []).select {|k,(f,l)| f == @library_file }.each do |cmd, (file, lineno)|
        scraped = CommentInspector.scrape(FileLibrary.read_library_file(file), lineno, MethodInspector.current_module)
        MethodInspector::METHODS.each do |e|
          if no_command_config_for(cmd, e)
            (@commands_hash[cmd] ||= {})[command_key(e)] = scraped[e]
          end
        end
      end
    end

    # translates from inspector attribute name to command attribute name
    def command_key(key)
      {:method_args=>:args, :desc=>:description}[key] || key
    end

    def no_command_config_for(cmd, attribute)
      !@commands_hash[cmd] || (@commands_hash[cmd] && !@commands_hash[cmd].key?(attribute))
    end
    #:startdoc:
  end
end