module Boson
  class Library
    include Loader
    class <<self
      def load(libraries, options={})
        libraries.map {|e| load_library(e, options) }.all?
      end

      def create(libraries, attributes={})
        libraries.map {|e| lib = new({:name=>e}.update(attributes)); add_library(lib); lib }
      end

      # ==== Options:
      # [:verbose] Prints the status of each library as its loaded. Default is false.
      def load_library(source, options={})
        (lib = load_once(source, options)) ? lib.after_load(options) : false
      end

      def reload_library(source, options={})
        if (lib = Boson.library(source))
          if lib.loaded
            command_size = Boson.commands.size
            if (result = rescue_load_action(lib.name, :reload, options) { lib.reload })
              lib.after_reload
              puts "Reloaded library #{source}: Added #{Boson.commands.size - command_size} commands" if options[:verbose]
            end
            result
          else
            puts "Library hasn't been loaded yet. Loading library #{source}..." if options[:verbose]
            load_library(source, options)
          end
        else
          puts "Library #{source} doesn't exist." if options[:verbose]
          false
        end
      end

      #:stopdoc:
      def add_library(lib)
        Boson.libraries.delete(Boson.library(lib.name))
        Boson.libraries << lib
      end

      def loaded?(lib_name)
        ((lib = Boson.library(lib_name)) && lib.loaded) ? true : false
      end

      def rescue_load_action(library, load_method, options={})
        yield
      rescue AppendFeaturesFalseError
      rescue LoaderError=>e
        FileLibrary.reset_file_cache(library.to_s)
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{e.message}", options
      rescue Exception=>e
        FileLibrary.reset_file_cache(library.to_s)
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{$!}" + "\n" +
          e.backtrace.slice(0,3).join("\n"), options
      ensure
        Inspector.remove_meta_methods if Inspector.enabled
      end

      def print_error_message(message, options)
        $stderr.puts message if !options[:index] || (options[:index] && options[:verbose])
      end

      def load_once(source, options={})
        rescue_load_action(source, :load, options) do
          lib = loader_create(source, options)
          if loaded?(lib.name)
            $stderr.puts "Library #{lib.name} already exists" if options[:verbose] && !options[:dependency]
            false
          else
            if lib.load
              lib
            else
              $stderr.puts "Unable to load library #{lib.name}." if !options[:dependency]
              false
            end
          end
        end
      end

      def loader_create(source, options={})
        lib_class = Library.handle_blocks.find {|k,v| v.call(source) } or raise(LoaderError, "Library #{source} not found.")
        lib_class[0].new(:name=>source, :options=>options)
      end

      attr_accessor :handle_blocks
      def handles(&block)
        (Library.handle_blocks ||= []) << [self,block]
      end
      #:startdoc:
    end

    ATTRIBUTES = [:gems, :dependencies, :commands, :loaded, :module, :name, :namespace]
    attr_reader *(ATTRIBUTES + [:commands_hash, :library_file, :object_namespace])
    attr_writer :namespace
    def initialize(hash)
      @name = set_name hash.delete(:name)
      @options = hash.delete(:options) || {}
      @loaded = false
      repo = set_repo
      @repo_dir = repo.dir
      @commands_hash = {}
      @commands = []
      set_config (repo.config[:libraries][@name] || {}).merge(hash)
      @commands_hash = repo.config[:commands].merge @commands_hash
      set_command_aliases(repo.config[:command_aliases])
      @namespace = true if Boson.repo.config[:auto_namespace] && @namespace.nil? &&
        !Boson::Runner.default_libraries.include?(@module)
      @namespace = clean_name if @namespace
    end

    # handles names under directories
    def clean_name
      @name[/\w+$/]
    end

    def set_name(name)
      name.to_s or raise ArgumentError, "New library missing required key :name"
    end

    def set_config(config)
      if (commands = config.delete(:commands))
        if commands.is_a?(Array)
          @commands += commands
        elsif commands.is_a?(Hash)
          @commands_hash = Util.recursive_hash_merge commands, @commands_hash
        end
      end
      set_command_aliases config.delete(:command_aliases) if config[:command_aliases]
      set_attributes config, true
    end

    def set_command_aliases(command_aliases)
      (command_aliases || {}).each do |cmd, cmd_alias|
        @commands_hash[cmd] ||= {}
        @commands_hash[cmd][:alias] ||= cmd_alias
      end
    end

    def set_repo
      Boson.repo
    end

    def set_attributes(hash, force=false)
      hash.each {|k,v| instance_variable_set("@#{k}", v) if instance_variable_get("@#{k}").nil? || force }
    end

    def after_load(options)
      create_commands
      Library.add_library(self)
      puts "Loaded library #{@name}" if options[:verbose]
      @created_dependencies.each do |e|
        e.create_commands
        Library.add_library(e)
        puts "Loaded library dependency #{e.name}" if options[:verbose]
      end
      remove_instance_variable("@created_dependencies")
      true
    end

    def after_reload
      Boson.commands.delete_if {|e| e.lib == @name } if @new_module
      create_commands(@new_commands)
    end

    # callback method
    def before_create_commands; end

    def create_commands(commands=@commands)
      if @except
        commands -= @except
        @except.each {|e| namespace_object.instance_eval("class<<self;self;end").send :undef_method, e }
      end
      before_create_commands
      commands.each {|e| Boson.commands << Command.create(e, self)}
      create_command_aliases(commands) if commands.size > 0 && !@no_alias_creation
      create_option_commands(commands)
    end

    def create_option_commands(commands)
      option_commands = command_objects(commands).select {|e| e.option_command? }
      accepted, rejected = option_commands.partition {|e| e.args(self) || e.arg_size }
      if @options[:verbose] && rejected.size > 0
        puts "Following commands cannot have options until their arguments are configured: " +
          rejected.map {|e| e.name}.join(', ')
      end
      accepted.each {|cmd| Scientist.create_option_command(namespace_object, cmd) }
    end

    def command_objects(names)
      Boson.commands.select {|e| names.include?(e.name) && e.lib == self.name }
    end

    def create_command_aliases(commands=@commands)
      @module ? Command.create_aliases(commands, @module) : check_for_uncreated_aliases
    end

    def check_for_uncreated_aliases
      if (found_commands = Boson.commands.select {|e| commands.include?(e.name)}) && found_commands.find {|e| e.alias }
        $stderr.puts "No aliases created for library #{@name} because it has no module"
      end
    end

    def library_type
      str = self.class.to_s[/::(\w+)Library$/, 1] || 'library'
      str.downcase.to_sym
    end

    def namespace_object
      @namespace_object ||= @namespace ? Boson.invoke(@namespace) : Boson.main_object
    end

    def marshal_dump
      [@name, @commands, @gems, @module.to_s, @repo_dir]
    end

    def marshal_load(ary)
      @name, @commands, @gems, @module, @repo_dir = ary
    end
  end
end