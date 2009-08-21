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

      #:stopdoc:
      def loaded?(lib_name)
        ((lib = Boson.libraries.find_by(:name=>lib_name)) && lib.loaded) ? true : false
      end

      def rescue_loader(library, load_method)
        yield
      rescue LoaderError=>e
        $stderr.puts "Unable to #{load_method} library #{library}. Reason: #{e.message}"
      rescue Exception
        $stderr.puts "Unable to #{load_method} library #{library}. Reason: #{$!}"
        $stderr.puts caller.slice(0,5).join("\n")
      end

      def load_once(library, options={})
        rescue_loader(library, :load) do
          lib = loader_create(library, options)
          if loaded?(lib.name)
            puts "Library #{lib.name} already exists" if options[:verbose] && !options[:dependency]
            false
          else
            result = lib.load
            $stderr.puts "Unable to load library #{lib.name}." if !result && !options[:dependency]
            result
          end
        end
      end

      # ==== Options:
      # [:verbose] Prints the status of each library as its loaded. Default is false.
      def load_library(library, options={})
        if (lib = load_once(library, options))
          lib.after_load
          puts "Loaded library #{lib.name}" if options[:verbose]
          lib.created_dependencies.each do |e|
            e.after_load
            puts "Loaded library dependency #{e.name}" if options[:verbose]
          end
          true
        else
          false
        end
      end

      def reload_library(library, options={})
        if (lib = Boson.libraries.find_by(:name=>library))
          if lib.loaded
            command_size = Boson.commands.size
            if (result = rescue_loader(lib.name, :reload) { lib.reload })
              puts "Reloaded library #{library}: Added #{Boson.commands.size - command_size} commands" if options[:verbose]
            end
            result
          else
            puts "Library hasn't been loaded yet. Loading library #{library}..." if options[:verbose]
            load_library(library, options)
          end
        else
          puts "Library #{library} doesn't exist." if options[:verbose]
          false
        end
      end

      def default_attributes
        {:detect_methods=>true, :gems=>[], :commands=>[], :call_methods=>[], :dependencies=>[]}
      end

      attr_accessor :handle_blocks
      def handles(&block)
        (Library.handle_blocks ||= []) << [self,block]
      end

      def loader_create(library, options={})
        lib_class = Library.handle_blocks.find {|k,v| v.call(library) }[0] or raise(LoaderError, "Library #{library} not found.")
        lib_class.new(:name=>library.to_s, :source=>library)
      end

      def library_file(library)
        File.join(Boson.dir, 'libraries', library + ".rb")
      end
      #:startdoc:
    end

    def initialize(hash)
      @name = hash[:name] or raise ArgumentError, "New library missing required key :name"
      @loaded = false
      @config = Boson.config[:libraries][@name] || {}
      set_attributes @config.merge(hash)
    end

    attr_accessor :module, :name
    attr_reader :gems, :created_dependencies, :dependencies, :commands, :loaded, :config

    def set_attributes(hash)
      hash.each {|k,v| instance_variable_set("@#{k}", v)}
    end

    def set_library_commands
      aliases = @commands.map {|e|
        Boson.config[:commands][e][:alias] rescue nil
      }.compact
      @commands -= aliases
      @commands.delete(@name) if @object_command
    end

    def after_load
      create_commands
      add_library
    end

    def create_commands(commands=@commands)
      if @except
        commands -= @except
        @except.each {|e| Boson.main_object.instance_eval("class<<self;self;end").send :undef_method, e }
      end
      commands.each {|e| Boson.commands << Command.create(e, @name)}
      create_command_aliases(commands) if commands.size > 0
    end

    def add_library
      if (existing_lib = Boson.libraries.find_by(:name => @name))
        Boson.libraries.delete(existing_lib)
      end
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

    def to_hash
      [:name, :module, :gems, :dependencies, :loaded, :commands].inject({}) {
        |h,e| h[e] = instance_variable_get("@#{e}"); h}
    end
  end
end