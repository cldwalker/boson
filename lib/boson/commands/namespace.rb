module Boson::Commands::Namespace
  def self.create(name, lib_module)
    module_eval %[
      def #{name}
        @#{name} ||= begin
          obj = Object.new
          class << obj; include #{lib_module} end
          def obj.commands
            #{lib_module}.instance_methods
          end
          # private
          def obj.method_missing(method, *args, &block)
            Boson.invoke(method, *args, &block)
          end
          obj
        end
      end
    ]
  end
end