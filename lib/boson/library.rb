module Boson
  class Library
    class <<self
      def load(libraries, options={})
        libraries.map {|e| Loader.load_library(e, options) }.all?
      end

      def create(libraries, attributes={})
        libraries.map {|e| lib = new({:name=>e}.update(attributes)); lib.add_library; lib }
      end

      #:stopdoc:
      def loaded?(lib_name)
        ((lib = Boson.libraries.find_by(:name=>lib_name)) && lib.loaded) ? true : false
      end

      def loader_create(hash, lib=nil)
        valid_attributes = [:call_methods, :except, :module, :gems, :commands, :dependencies, :created_dependencies]
        lib ||= new(:name=>hash.delete(:name))
        hash.delete_if {|k,v| !valid_attributes.include?(k) }
        lib.set_attributes hash.merge(:loaded=>true)
        lib.set_library_commands
        lib
      end
      #:startdoc:
    end

    def initialize(hash)
      @name = hash[:name] or raise ArgumentError, "New library missing required key :name"
      @loaded = false
      @config = Boson.config[:libraries][@name] || {}
      set_attributes @config.merge(hash)
    end

    attr_accessor :module
    attr_reader :gems, :created_dependencies, :dependencies, :commands, :name, :loaded, :config

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