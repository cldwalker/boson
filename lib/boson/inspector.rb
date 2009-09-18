# Serves as dealer between libraries and inspectors of method metadata
# acquired by inspectors i.e. comment metadata or method calls before methods.
module Boson::Inspector
  extend self
  attr_reader :enabled

  def add_meta_methods
    @enabled = true
    ::Module.module_eval %[
      def new_method_added(method)
        Boson::MethodInspector.new_method_added(self, method)
      end

      def options(opts)
        Boson::MethodInspector.options(self, opts)
      end

      def desc(description)
        Boson::MethodInspector.desc(self, description)
      end

      alias_method :_old_method_added, :method_added
      alias_method :method_added, :new_method_added
    ]
  end

  def remove_meta_methods
    ::Module.module_eval %[
      remove_method :desc
      remove_method :options
      alias_method :method_added, :_old_method_added
    ]
    @enabled = false
  end
end