module Boson
  class Library
    class <<self
      def load(libraries, options={})
        libraries.map {|e| Loader.load_library(e, options) }.all?
      end

      def create(libraries, options={})
        libraries.each {|e| new(:name=>e).add_library }
      end

      #:stopdoc:
      def default_attributes
        {:loaded=>false, :detect_methods=>true, :gems=>[], :commands=>[], :except=>[], :call_methods=>[], :dependencies=>[],
          :force=>false, :created_dependencies=>[]}
      end

      def config_attributes(lib)
        default_attributes.merge(:name=>lib.to_s).merge!(Boson.config[:libraries][lib.to_s] || {})
      end

      def loaded?(lib_name)
        ((lib = Boson.libraries.find_by(:name=>lib_name)) && lib.loaded) ? true : false
      end
      #:startdoc:
    end

    def initialize(hash)
        @name = hash[:name] or raise ArgumentError, "New library missing required key :name"
        hash = self.class.config_attributes(hash[:name]).merge(hash)
        set_attributes(hash)
        set_library_commands
    end

    attr_accessor :module
    attr_reader :gems, :created_dependencies, :dependencies, :loaded, :commands, :name

    def set_attributes(hash)
      @module = hash[:module]
      @loaded = hash[:loaded]
      @gems = hash[:gems]
      @commands = hash[:commands]
      @except = hash[:except]
      @call_methods = hash[:call_methods]
      @dependencies = hash[:dependencies]
      @created_dependencies = hash[:created_dependencies]
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
        Boson.libraries << self
      else
        Boson.libraries << self
      end
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
      (self.class.default_attributes.keys + [:module, :name]).inject({}) {|h,e| h[e] = send(e) rescue nil; h}
    end
  end
end