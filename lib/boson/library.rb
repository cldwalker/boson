module Boson
  class Library < ::Hash
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
          :force=>false, :created_dependencies=>[], :name=>nil}
      end

      def config_attributes(lib)
        default_attributes.merge(:name=>lib.to_s).merge!(Boson.config[:libraries][lib.to_s] || {})
      end

      def loaded?(lib_name)
        ((lib = Boson.libraries.find_by(:name=>lib_name)) && lib[:loaded]) ? true : false
      end
      #:startdoc:
    end

    def initialize(hash)
      super
      raise ArgumentError, "New library missing required key :name" unless hash[:name]
      hash = self.class.config_attributes(hash[:name]).merge(hash)
      replace(hash)
      set_library_commands
    end

    def set_library_commands
      aliases = self[:commands].map {|e|
        Boson.config[:commands][e][:alias] rescue nil
      }.compact
      self[:commands] -= aliases
      self[:commands].delete(self[:name]) if self[:object_command]
    end

    def after_load
      create_commands
      add_library
    end

    def create_commands(commands=self[:commands])
      if self[:except]
        commands -= self[:except]
        self[:except].each {|e| Boson.main_object.instance_eval("class<<self;self;end").send :undef_method, e }
      end
      commands.each {|e| Boson.commands << Command.create(e, self[:name])}
      create_command_aliases(commands) if commands.size > 0
    end

    def add_library
      if (existing_lib = Boson.libraries.find_by(:name => self[:name]))
        existing_lib.merge!(self)
      else
        Boson.libraries << self
      end
    end

    def create_command_aliases(commands=self[:commands])
      if self[:module]
        Command.create_aliases(commands, self[:module])
      else
        if (found_commands = Boson.commands.select {|e| commands.include?(e.name)}) && found_commands.find {|e| e.alias }
          $stderr.puts "No aliases created for library #{self[:name]} because it has no module"
        end
      end
    end

    def to_hash
      (self.class.default_attributes.keys + [:module]).inject({}) {|h,e| h[e] = send(e) rescue nil; h}
    end

    def method_missing(method, *args, &block)
      method = method.to_s
      if method =~ /^(\w+)=$/ && has_key?($1.to_sym)
        self[$1.to_sym] = args.first
      elsif method =~ /^(\w+)$/ && has_key?($1.to_sym)
        self[$1.to_sym]
      else
        super(method.to_sym, *args, &block)
      end
    end
  end
end