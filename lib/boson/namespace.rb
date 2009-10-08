module Boson
  # Used in all things namespace.
  class Namespace
    # Hash of created namespace names to namespace objects
    def self.namespaces
      @namespaces ||= {}
    end

    # Creates a namespace given its name and the library it belongs to.
    def self.create(name, library)
      if library.object_namespace && library.module.instance_methods.map {|e| e.to_s}.include?(name)
        library.include_in_universe
        create_object_namespace(name, library)
      else
        create_basic_namespace(name, library)
      end
    end
    #:stopdoc:

    def self.create_object_namespace(name, library)
      obj = library.namespace_object
      obj.instance_eval("class<<self;self;end").send(:define_method, :boson_commands) {
        self.class.instance_methods(false) }
      obj.instance_eval("class<<self;self;end").send(:define_method, :object_delegate?) { true }
      namespaces[name.to_s] = obj
    end

    def self.create_basic_namespace(name, library)
      namespaces[name.to_s] = new(name, library)
      Commands::Namespace.send(:define_method, name) { Boson::Namespace.namespaces[name.to_s] }
    end

    def initialize(name, library)
      raise ArgumentError unless library.module
      @name, @library = name.to_s, library
      class <<self; self end.send :include, @library.module
    end

    def object_delegate?; false; end

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