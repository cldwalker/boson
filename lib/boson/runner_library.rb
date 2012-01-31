module Boson
  # Library created by Runner
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
      @runner = runner #reference needed elsewhere
      @runner.to_s[/[^:]+$/].downcase
    end

    # Since Boson expects libraries to be modules, creates a temporary module
    # and delegates its methods to it
    def load_source_and_set_module
      @module = Util.create_module Boson::Commands, @name
      MethodInspector.mod_store[@module] = MethodInspector.mod_store.delete(@runner)
      self.class.delegate_runner_methods @runner, @module
    end
  end
end
