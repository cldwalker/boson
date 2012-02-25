module Boson
  # Scrapes and processes method attributes with the inspectors (MethodInspector, CommentInspector
  # and ArgumentInspector) and hands off the data to FileLibrary objects.
  #
  # === Method Attributes
  # Method attributes refer to (commented) Module methods placed before a command's method
  # in a FileLibrary module:
  #   module SomeMod
  #      # @render_options :fields=>%w{one two}
  #      # @config :alias=>'so'
  #      options :verbose=>:boolean
  #      option :count, :numeric
  #      # Something descriptive perhaps
  #      def some_method(opts)
  #        # ...
  #      end
  #   end
  #
  # Method attributes serve as configuration for a method's command. All attributes should only be called once per
  #   method except for option. Available method attributes:
  # * config: Hash to define any command attributes (see Command.new).
  # * desc: String to define a command's description for a command. Defaults to first commented line above a method.
  # * options: Hash to define an OptionParser object for a command's options.
  # * option: Option name and value to be merged in with options. See OptionParser for what an option value can be.
  # * render_options: Hash to define an OptionParser object for a command's local/global render options (see View).
  #
  # When deciding whether to use commented or normal Module methods, remember that commented Module methods allow
  # independence from Boson (useful for testing). See CommentInspector for more about commented method attributes.
  module Inspector
    extend self
    attr_reader :enabled

    # Enable scraping by overridding method_added to snoop on a library while it's
    # loading its methods.
    def enable
      @enabled = true
      body = MethodInspector::ALL_METHODS.map {|e|
        %[def #{e}(*args)
            Boson::MethodInspector.#{e}(self, *args)
          end]
      }.join("\n") +
      %[
        def new_method_added(method)
          Boson::MethodInspector.new_method_added(self, method)
        end

        alias_method :_old_method_added, :method_added
        alias_method :method_added, :new_method_added

        alias_method :_old_module_eval, :module_eval

        def module_eval(*args)
          # will return if called from disable
          Boson::MethodInspector.parse_mod(self, args.first)
          _old_module_eval(*args)
        end
      ]
    ::Module.module_eval body
    end

    # Disable scraping method data.
    def disable
      @enabled = false
      ::Module.module_eval %[
        Boson::MethodInspector::ALL_METHODS.each {|e| remove_method e }
        alias_method :method_added, :_old_method_added
        alias_method :module_eval, :_old_module_eval                       ]
    end

    # Adds method attributes scraped for the library's module to the library's commands.
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
      (MethodInspector::METHODS + [:args]).each do |key|
        (@store[key] || []).each do |cmd, val|
          @commands_hash[cmd] ||= {}
          add_valid_data_to_config(key, val, cmd)
        end
      end
    end

    def add_valid_data_to_config(key, value, cmd)
      if valid_attr_value?(key, value)
        add_scraped_data_to_config(key, value, cmd)
      else
        if Runner.debug
          warn "DEBUG: Command '#{cmd}' has #{key.inspect} attribute with invalid value '#{value.inspect}'"
        end
      end
    end

    def add_scraped_data_to_config(key, value, cmd)
      if value.is_a?(Hash)
        if key == :config
          @commands_hash[cmd] = Util.recursive_hash_merge value, @commands_hash[cmd]
        else
          @commands_hash[cmd][key] = Util.recursive_hash_merge value, @commands_hash[cmd][key] || {}
        end
      else
        @commands_hash[cmd][key] ||= value
      end
    end

    def valid_attr_value?(key, value)
      return true if (klass = MethodInspector::METHOD_CLASSES[key]).nil?
      value.is_a?(klass) || value.nil?
    end

    def add_comment_scraped_data
      (@store[:method_locations] || []).select {|k,(f,l)| f == @library_file }.each do |cmd, (file, lineno)|
        scraped = CommentInspector.scrape(FileLibrary.read_library_file(file), lineno, MethodInspector.current_module)
        @commands_hash[cmd] ||= {}
        MethodInspector::METHODS.each do |e|
          add_valid_data_to_config(e, scraped[e], cmd)
        end
      end
    end
    #:startdoc:
  end
end
