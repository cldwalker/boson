module Boson
  # Used in all things namespace.
  class Namespace
    # Hash of created namespace names to namespace objects
    def self.namespaces
      @namespaces ||= {}
    end

    # Creates a namespace given its name and the library it belongs to.
    def self.create(name, library)
      namespaces[name.to_s] = new(name, library)
      Commands::Namespace.send(:define_method, name) { Boson::Namespace.namespaces[name.to_s] }
    end

    def initialize(name, library)
      raise ArgumentError unless library.module
      @name, @library = name.to_s, library
      class <<self; self end.send :include, @library.module
    end

    def method_missing(method, *args, &block)
      Boson.can_invoke?(method) ? Boson.invoke(method, *args, &block) : super
    end

    #:startdoc:
    # List of subcommands for the namespace.
    def boson_commands
      @library.module.instance_methods.map {|e| e.to_s }
    end
  end
end