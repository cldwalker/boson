module Boson
  class RunnerLibrary < Library
    handles {|source|
      source.is_a?(Module) && source.ancestors.include?(Runner)
    }

    def self.delegate_runner_methods(runner, mod)
      mod.module_eval do
        runner.public_instance_methods(false).each do |meth|
          define_method(meth) do |*args, &block|
            runner.new.send(meth, *args, &block)
          end
        end
      end
    end

    def set_name(runner)
      @module = Util.create_module Boson::Commands, runner.app_name
      MethodInspector.mod_store[@module] = MethodInspector.mod_store.delete(runner)
      self.class.delegate_runner_methods runner, @module
      runner.app_name
    end
  end
end
