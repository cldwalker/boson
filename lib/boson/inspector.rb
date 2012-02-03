module Boson
  # Scrapes and processes method attributes with MethodInspector and hands off
  # the data to Library objects.
  #
  # === Method Attributes
  # Method attributes refer to methods placed before a command's method in a
  # library:
  #   class SomeRunner < Boson::Runner
  #      options :verbose=>:boolean
  #      option :count, :numeric
  #      # Something descriptive perhaps
  #      def some_method(opts)
  #        # ...
  #      end
  #   end
  #
  # Method attributes serve as configuration for a method's command. All
  # attributes should only be called once per method except for option.
  # Available method attributes:
  # * config: Hash to define any command attributes (see Command.new).
  # * desc: String to define a command's description for a command. Defaults to first commented line above a method.
  # * options: Hash to define an OptionParser object for a command's options.
  # * option: Option name and value to be merged in with options. See OptionParser for what an option value can be.
  class Inspector
    class << self; attr_reader :enabled; end

    # Enable scraping by overridding method_added to snoop on a library while
    # it's loading its methods.
    def self.enable(options = {})
      method_inspector_meth = options[:all_classes] ?
        :new_method_added : :safe_new_method_added
      klass = options[:module] || ::Module
      @enabled = true unless options[:module]

      body = MethodInspector::ALL_METHODS.map {|e|
        %[def #{e}(*args)
            Boson::MethodInspector.#{e}(self, *args)
          end]
      }.join("\n") +
      %[
        def new_method_added(method)
          Boson::MethodInspector.#{method_inspector_meth}(self, method)
        end

        alias_method :_old_method_added, :method_added
        alias_method :method_added, :new_method_added
      ]
      klass.module_eval body
    end

    # Disable scraping method data.
    def self.disable
      ::Module.module_eval %[
        Boson::MethodInspector::ALL_METHODS.each {|e| remove_method e }
        alias_method :method_added, :_old_method_added
      ]
      @enabled = false
    end

    # Adds method attributes to the library's commands
    def self.add_method_data_to_library(library)
      new(library).add_data
    end

    def initialize(library)
      @commands_hash = library.commands_hash
      @library_file = library.library_file
      MethodInspector.current_module = library.module
      @store = MethodInspector.store
    end

    def add_data
      add_method_scraped_data
    end

    private
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
        if Boson.debug
          warn "DEBUG: Command '#{cmd}' has #{key.inspect} attribute with " +
            "invalid value '#{value.inspect}'"
        end
      end
    end

    def add_scraped_data_to_config(key, value, cmd)
      if value.is_a?(Hash)
        if key == :config
          @commands_hash[cmd] = Util.recursive_hash_merge value, @commands_hash[cmd]
        else
          @commands_hash[cmd][key] = Util.recursive_hash_merge value,
            @commands_hash[cmd][key] || {}
        end
      else
        @commands_hash[cmd][key] ||= value
      end
    end

    def valid_attr_value?(key, value)
      return true if (klass = MethodInspector::METHOD_CLASSES[key]).nil?
      value.is_a?(klass) || value.nil?
    end
  end
end
