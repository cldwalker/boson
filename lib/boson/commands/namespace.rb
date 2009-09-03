module Boson::Commands::Namespace
  def self.create(name, lib_module)
    module_eval %[
      def #{name}
        @#{name} ||= begin
          obj = Object.new
          obj.instance_eval("class<<self;self;end").send :include, #{lib_module}
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