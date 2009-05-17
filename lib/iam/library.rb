module Iam
  class Library < ::Hash
    extend Config
    def initialize(hash)
      super
      replace(hash)
    end

    class<<self
      def library_config(library=nil)
        @library_config ||= {:loaded=>false, :detect_methods=>true, :name=>library.to_s, :gems=>[]}.merge!(config[:libraries][library.to_s] || {})
      end

      def set_library_config(library)
        if library.is_a?(Module)
          library_config(Util.underscore(library)).merge!(:module=>library)
        else
          library_config(library)
        end
      end

      def add_gems_to_library_config(gems)
        library_config.merge! :gems=>(library_config[:gems] + gems)
      end

      def load_and_create(library, options={})
        set_library_config(library)
        begin
        if library.is_a?(Module)
          added_methods = detect_added_methods { initialize_library_module(library) }
          create_loaded_library(library_config[:name], :commands=>added_methods)
        else
          #try gem
          begin
            added_methods = detect_added_methods { safe_require "libraries/#{library}"}
            if (gem_module = Util.constantize("iam/libraries/#{library}"))
              added_methods += detect_added_methods { initialize_library_module(gem_module) }
              library_config.merge!(:module=>gem_module)
            else
              added_methods += detect_added_methods { safe_require library.to_s }
            end
            return create_loaded_library(library, :commands=>added_methods)
          rescue
            puts "Failed to load gem library #{library}"
            puts caller.slice(0,5).join("\n")
          end
          puts "Library '#{library}' not found"
        end
        rescue LoadError
          puts "Failed to load '#{library}'"
        rescue Exception
          puts "Failed to load '#{library}'"
          puts "Reason: #{$!}"
          puts caller.slice(0,5).join("\n")
        end
      end

      def detect_added_methods
        original_gems = Gem.loaded_specs.keys if Object.const_defined? :Gem
        original_object_methods = Object.instance_methods
        original_instance_methods = Iam.base_object.instance_eval("class<<self;self;end").instance_methods
        yield
        add_gems_to_library_config(Gem.loaded_specs.keys - original_gems) if Object.const_defined? :Gem
        return library_config[:detect_methods] ? (Object.instance_methods - original_object_methods + 
          Iam.base_object.instance_eval("class<<self;self;end").instance_methods - original_instance_methods).uniq :
          Object.instance_methods - original_object_methods
      end

      def initialize_library_module(lib_module)
        lib_module.send(:init) if lib_module.respond_to?(:init)
        Iam.base_object.extend(lib_module)
        #td: eval in base_object without having to intrude with extend
        (library_config[:load] || []).each do |m|
          Iam.base_object.send m
        end
      end

      def safe_require(lib)
        begin
          require lib
        rescue LoadError
          false
        end
      end

      def create_loaded_library(name, lib_hash={})
        create(name, lib_hash.merge(:loaded=>true))
      end

      # attributes: name, type, loaded, commands
      def create(name, lib_hash={})
        library_obj = {:loaded=>false, :name=>name.to_s}.merge(library_config(name)).merge(lib_hash)
        set_library_commands(library_obj)
        @library_config = nil
        new(library_obj)
      end

      def set_library_commands(library_obj)
        library_obj[:commands] ||= []
        if library_obj[:module]
          aliases = library_obj[:module].instance_methods.map {|e|
            config[:commands][e][:alias] rescue nil
          }.compact
          library_obj[:commands] = (library_obj[:commands] + library_obj[:module].instance_methods).uniq - aliases
        end
      end
    end
  end
end
