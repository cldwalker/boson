module Boson
  # Collection of utility methods used throughout Boson.
  module Util
    extend self
    # From Rails ActiveSupport, converts a camelcased string to an underscored string:
    # 'Boson::MethodInspector' -> 'boson/method_inspector'
    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
       gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
       gsub(/([a-z\d])([A-Z])/,'\1_\2').
       tr("-", "_").
       downcase
    end

    # From Rails ActiveSupport, does the reverse of underscore:
    # 'boson/method_inspector' -> 'Boson::MethodInspector'
    def camelize(string)
      Hirb::Util.camelize(string)
    end

    # Converts a module/class string to the actual constant.
    # Returns nil if not found.
    def constantize(string)
      any_const_get(camelize(string))
    end

    # Returns a constant like const_get() no matter what namespace it's nested in.
    # Returns nil if the constant is not found.
    def any_const_get(name)
      Hirb::Util.any_const_get(name)
    end

    # Detects new object/kernel methods, gems and modules created within a block.
    # Returns a hash of what's detected.
    # Valid options and possible returned keys are :methods, :object_methods, :modules, :gems.
    def detect(options={}, &block)
      options = {:methods=>true, :object_methods=>true}.merge!(options)
      original_gems = Gem.loaded_specs.keys if Object.const_defined? :Gem
      original_object_methods = Object.instance_methods
      original_instance_methods = class << Boson.main_object; instance_methods end
      original_modules = modules if options[:modules]
      block.call
      detected = {}
      detected[:methods] = options[:methods] ? (class << Boson.main_object; instance_methods end -
        original_instance_methods) : []
      detected[:methods] -= (Object.instance_methods - original_object_methods) unless options[:object_methods]
      detected[:gems] = Gem.loaded_specs.keys - original_gems if Object.const_defined? :Gem
      detected[:modules] = modules - original_modules if options[:modules]
      detected
    end

    # Safely calls require, returning false if LoadError occurs.
    def safe_require(lib)
      begin
        require lib
        true
      rescue LoadError
        false
      end
    end

    # Returns all modules that currently exist.
    def modules
      all_modules = []
      ObjectSpace.each_object(Module) {|e| all_modules << e}
      all_modules
    end

    # Creates a module under a given base module and possible name. If the module already exists or conflicts
    # per top_level_class_conflict, it attempts to create one with a number appended to the name.
    def create_module(base_module, name)
      desired_class = camelize(name)
      possible_suffixes = [''] + %w{1 2 3 4 5 6 7 8 9 10}
      if (suffix = possible_suffixes.find {|e| !base_module.const_defined?(desired_class+e) &&
        !top_level_class_conflict(base_module, "#{base_module}::#{desired_class}#{e}") })
        base_module.const_set(desired_class+suffix, Module.new)
      end
    end

    # Behaves just like the unix which command, returning the full path to an executable based on ENV['PATH'].
    def which(command)
      ENV['PATH'].split(File::PATH_SEPARATOR).map {|e| File.join(e, command) }.find {|e| File.exists?(e) }
    end

    # Deep copies any object if it can be marshaled. Useful for deep hashes.
    def deep_copy(obj)
      Marshal::load(Marshal::dump(obj))
    end

    # Recursively merge hash1 with hash2.
    def recursive_hash_merge(hash1, hash2)
      hash1.merge(hash2) {|k,o,n| (o.is_a?(Hash)) ? recursive_hash_merge(o,n) : n}
    end

    # From Rubygems, determine a user's home.
    def find_home
      Hirb::Util.find_home
    end

    # Returns name of top level class that conflicts if it exists. For example, for base module Boson::Commands,
    # Boson::Commands::Alias conflicts with Alias if Alias exists.
    def top_level_class_conflict(base_module, conflicting_module)
      (conflicting_module =~ /^#{base_module}.*::([^:]+)/) && Object.const_defined?($1) && $1
    end

    # Regular expression search of a list with underscore anchoring of words.
    # For example 'some_dang_long_word' can be specified as 's_d_l_w'.
    def underscore_search(input, list, first_match=false)
      meth = first_match ? :find : :select
      return (first_match ? input : [input]) if list.include?(input)
      input = input.to_s
      if input.include?("_")
        underscore_regex = input.split('_').map {|e| Regexp.escape(e) }.join("([^_]+)?_")
        list.send(meth) {|e| e.to_s =~ /^#{underscore_regex}/ }
      else
        escaped_input = Regexp.escape(input)
        list.send(meth) {|e| e.to_s =~ /^#{escaped_input}/ }
      end
    end
  end
end
