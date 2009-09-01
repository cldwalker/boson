module Boson
  class Library
    include Loader
    class <<self
      def load(libraries, options={})
        libraries.map {|e| load_library(e, options) }.all?
      end

      def create(libraries, attributes={})
        libraries.map {|e| lib = new({:name=>e}.update(attributes)); lib.add_library; lib }
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
      def loaded?(lib_name)
        ((lib = Boson.library(lib_name)) && lib.loaded) ? true : false
      end

      def rescue_load_action(library, load_method, options={})
        yield
      rescue LoaderError=>e
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{e.message}", options
      rescue Exception=>e
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{$!}" +
          e.backtrace.slice(0,3).join("\n"), options
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
        lib_class[0].new(:name=>source.to_s, :source=>source, :options=>options)
      end

      attr_accessor :handle_blocks
      def handles(&block)
        (Library.handle_blocks ||= []) << [self,block]
      end

      def library_file(library)
        File.join(Boson.commands_dir, library + ".rb")
      end
      #:startdoc:
    end

    attr_reader :gems, :dependencies, :commands, :loaded, :module, :name
    def initialize(hash)
      @name = hash.delete(:name) or raise ArgumentError, "New library missing required key :name"
      @options = hash.delete(:options) || {}
      @loaded = false
      @config = Boson.config[:libraries][@name] || {}
      set_attributes @config.merge(hash)
    end

    def set_attributes(hash)
      hash.each {|k,v| instance_variable_set("@#{k}", v)}
    end

    def set_library_commands
      aliases = @commands.map {|e|
        Boson.config[:commands][e][:alias] rescue nil
      }.compact
      @commands -= aliases
      @commands.delete(namespace_command) if @namespace
    end

    def after_load(options)
      set_library_commands
      create_commands
      add_library
      puts "Loaded library #{@name}" if options[:verbose]
      @created_dependencies.each do |e|
        e.create_commands
        e.add_library
        puts "Loaded library dependency #{e.name}" if options[:verbose]
      end
      @created_dependencies = nil
      true
    end

    def after_reload
      Boson.commands.delete_if {|e| e.lib == @name } if @new_module
      create_commands(@new_commands)
    end

    def create_commands(commands=@commands)
      if @except
        commands -= @except
        @except.each {|e| namespace_object.instance_eval("class<<self;self;end").send :undef_method, e }
      end
      commands.each {|e| Boson.commands << Command.create(e, @name)}
      create_command_aliases(commands) if commands.size > 0
    end

    def add_library
      Boson.libraries.delete(Boson.library(@name))
      Boson.libraries << self
    end

    def create_command_aliases(commands=@commands)
      if @module
        Command.create_aliases(commands, @module)
      else
        if (found_commands = Boson.commands.select {|e| commands.include?(e.name)}) && found_commands.find {|e| e.alias }
          $stderr.puts "No aliases created for library #{@name} because it has no module"
        end
      end
    end

    def library_type
      str = self.class.to_s[/::(\w+)Library$/, 1] || 'library'
      str.downcase.to_sym
    end

    def marshalize
      @namespace_object = @source = nil
      @module = @module.to_s
      @loaded = false
      self
    end
  end
end