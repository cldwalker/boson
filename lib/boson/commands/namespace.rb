module Boson::Commands::Namespace
  def self.create(name, lib_module)
    module_eval %[
      def #{name}
        @#{name} ||= begin
          obj = Object.new
          class << obj; include #{lib_module} end
          def obj.boson_commands
            #{lib_module}.instance_methods
          end
          obj
        end
      end
    ]
  end

  def self.add_universe(object)
    class << object
      unless method_defined?(:boson_commands)
        def boson_commands; []; end
      end

      def method_missing(method, *args, &block)
        Boson.main_object.respond_to?(method) ? Boson.invoke(method, *args, &block) : super
      end
    end
  end
end