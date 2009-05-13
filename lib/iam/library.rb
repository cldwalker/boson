module Iam
  class Library < ::Hash
    extend Config
    def initialize(hash)
      super
      replace(hash)
    end

    class<<self
      def load_and_create(library, options={})
        begin
        if (library.is_a?(Symbol) || library.is_a?(String)) && Iam.base_object.respond_to?(library, true)
          Iam.base_object.send(library)
          return create_loaded_library(library, :method)
        end

        if library.is_a?(Module) || (module_library = Util.constantize(library))
          library = module_library if module_library
          added_methods = detect_added_methods { initialize_library_module(library) }
          create_loaded_library(Util.underscore(library), :module, :module=>library, :commands=>added_methods)
        #td: eval in base_object without having to intrude with extend
        else
          #try gem
          begin
            added_methods = detect_added_methods { safe_require "libraries/#{library}"}
            if (gem_module = Util.constantize("iam/libraries/#{library}"))
              added_methods += detect_added_methods { initialize_library_module(gem_module) }
              library_hash = {:module=>gem_module}
            else
              added_methods += detect_added_methods { safe_require library.to_s }
              library_hash = {}
            end
            return create_loaded_library(library, :gem, library_hash.merge(:commands=>added_methods))
          rescue
            puts "Failed to load gem library"
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
        original_object_methods = Object.methods
        original_instance_methods = Iam.base_object.instance_eval("class<<self;self;end").instance_methods
        yield
        Object.methods - original_object_methods
        # return (Object.methods - original_object_methods + Iam.base_object.instance_eval("class<<self;self;end").instance_methods - 
        #   original_instance_methods).uniq
      end

      def initialize_library_module(lib_module)
        lib_module.send(:init) if lib_module.respond_to?(:init)
        Iam.base_object.extend(lib_module)
      end

      def safe_require(lib)
        begin
          require lib
        rescue LoadError
          false
        end
      end

      def create_loaded_library(name, library_type, lib_hash={})
        create(name, library_type, lib_hash.merge(:loaded=>true))
      end

      # attributes: name, type, loaded, commands
      def create(name, library_type=nil, lib_hash={})
        library_obj = {:loaded=>false, :name=>name.to_s}.merge(config[:libraries][name.to_s] || {}).merge(lib_hash)
        library_obj[:type] = library_type if library_type
        set_library_commands(library_obj)
        puts "Loaded #{library_type} library '#{name}'" if $DEBUG
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
        # library_obj[:commands].uniq!
      end
    end
  end
end
