module Boson
  class Library < ::Hash
    class <<self
      def load(libraries, options={})
        libraries.each {|e| load_library(e, options) }
      end

      def create(libraries, options={})
        libraries.each {|e| create_library(e) }
      end

      #:stopdoc:
      def create_library(*args)
        lib = Loader.create(*args)
        lib.add_lib_commands
        lib.add_library
        lib
      end

      def load_library(library, options={})
        if (lib = Loader.load_and_create(library, options))
          lib.add_library
          lib.add_lib_commands
          puts "Loaded library #{lib[:name]}" if options[:verbose]
          lib[:created_dependencies].each do |e|
            e.add_library
            e.add_lib_commands
            puts "Loaded library dependency #{e[:name]}" if options[:verbose]
          end
          true
        else
          $stderr.puts "Unable to load library #{library}" if lib.is_a?(FalseClass)
          false
        end
      end

      def default_attributes
        {:loaded=>false, :detect_methods=>true, :gems=>[], :commands=>[], :except=>[], :call_methods=>[], :dependencies=>[],
          :force=>false, :created_dependencies=>[]}
      end

      def loaded?(lib_name)
        ((lib = Boson.libraries.find_by(:name=>lib_name)) && lib[:loaded]) ? true : false
      end
      #:startdoc:
    end

    def initialize(hash)
      super
      replace(hash)
    end

    def add_lib_commands
      if self[:loaded]
        if self[:except]
          self[:commands] -= self[:except]
          self[:except].each {|e| Boson.main_object.instance_eval("class<<self;self;end").send :undef_method, e }
        end
        self[:commands].each {|e| Boson.commands << Command.create(e, self[:name])}
        if self[:commands].size > 0
          create_command_aliases
        end
      end
    end

    def add_library
      if (existing_lib = Boson.libraries.find_by(:name => self[:name]))
        existing_lib.merge!(self)
      else
        Boson.libraries << self
      end
    end

    def create_command_aliases
      if self[:module]
        Command.create_aliases(self[:commands], self[:module])
      else
        if (commands = Boson.commands.select {|e| self[:commands].include?(e.name)}) && commands.find {|e| e.alias }
          $stderr.puts "No aliases created for lib #{self[:name]} because there is no lib module"
        end
      end
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
