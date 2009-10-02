module Boson
  class Namespace
    def self.create_object_namespace(name, obj)
      obj.instance_eval("class<<self;self;end").send(:define_method, :boson_commands) {
        self.class.instance_methods(false) }
      obj.instance_eval("class<<self;self;end").send(:define_method, :object_delegate?) { true }
      namespaces[name.to_s] = obj
    end

    def self.namespaces
      @namespaces ||= {}
    end

    def self.create(name, library)
      namespaces[name.to_s] = new(name, library)
      Commands::Namespace.send(:define_method, name) { Boson::Namespace.namespaces[name.to_s] }
    end

    def initialize(name, library)
      raise ArgumentError unless library.module
      @name, @library = name.to_s, library
      class <<self; self end.send :include, @library.module
    end

    def boson_commands
      @library.module.instance_methods
    end

    def object_delegate?; false; end

    def method_missing(method, *args, &block)
      Boson.main_object.respond_to?(method) ? Boson.invoke(method, *args, &block) : super
    end
  end
end