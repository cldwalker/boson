module Boson
  module Commands
    module ObjectCommands
      def self.create(name, lib_module)
        module_eval %[
          def #{name}
            @#{name} ||= begin
              obj = Object.new.extend(#{lib_module})
              def obj.commands
                #{lib_module}.instance_methods
              end
              private
              def obj.method_missing(method, *args, &block)
                Boson.main_object.send(method, *args, &block)
              end
              obj
            end
          end
        ]
      end
    end
  end
end