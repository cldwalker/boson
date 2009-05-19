module Iam
  class Library < ::Hash
    class LoadingDependencyError < StandardError; end
    extend Config
    def initialize(hash)
      super
      replace(hash)
    end

    class<<self
      def default_library
        {:loaded=>false, :detect_methods=>true, :gems=>[], :commands=>[], :except=>[], :call_methods=>[], :dependencies=>[]}
      end

      def library_config(library=nil)
        @library_config ||= default_library.merge(:name=>library.to_s).merge!(config[:libraries][library.to_s] || {})
      end

      def reset_library_config; @library_config = nil; end

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

      def add_commands_to_library_config(commands)
        library_config.merge! :commands=>(library_config[:commands] + commands)
      end

      def load_and_create(library, options={})
        set_library_config(library)
        load(library, options) && create(library_config[:name], :loaded=>true)
      rescue LoadingDependencyError=>e
        puts e.message
        false
      end

      def load_dependencies(library, options)
        deps = []
        if !library_config[:dependencies].empty?
          dependencies = library_config[:dependencies]
          reset_library_config
          dependencies.each do |e|
            next if Manager.library_loaded?(e)
            if (dep = load_and_create(e, options))
              deps << dep
            else
              raise LoadingDependencyError, "Failed to load dependency #{e}"
            end
          end
          set_library_config(library)
        end
        library_config[:created_dependencies] = deps
      end

      def load(library, options={})
        load_dependencies(library, options) 
        if library.is_a?(Module)
          added_methods = detect_additions { initialize_library_module(library) }
          add_commands_to_library_config(added_methods)
        else
          added_methods = detect_additions(:modules=>true) { safe_require "libraries/#{library}"}
          if (gem_module = Util.constantize("iam/libraries/#{library}"))
            added_methods += detect_additions { initialize_library_module(gem_module) }
            library_config.merge!(:module=>gem_module)
          else
            added_methods += detect_additions { safe_require library.to_s }
          end
          add_commands_to_library_config(added_methods)
        end
        is_valid_library
      rescue LoadingDependencyError
        raise
      rescue Exception
        puts "Failed to load '#{library}'"
        puts "Reason: #{$!}"
        puts caller.slice(0,5).join("\n")
        false
      end

      def is_valid_library
        !(library_config[:commands].empty? && library_config[:gems].empty? && !library_config.has_key?(:module))
      end

      def detect_additions(options={}, &block)
        detected = Util.detect(options.merge(:detect_methods=>library_config[:detect_methods]), &block)
        add_gems_to_library_config(detected[:gems]) if detected[:gems]
        detected[:methods]
      end

      def initialize_library_module(lib_module)
        lib_module.send(:init) if lib_module.respond_to?(:init)
        if library_config[:object_command]
          create_object_command(lib_module)
        else
          Iam.base_object.extend(lib_module)
        end
        #td: eval in base_object without having to intrude with extend
        library_config[:call_methods].each do |m|
          Iam.base_object.send m
        end
      end

      def create_object_command(lib_module)
        ObjectCommands.module_eval %[
          def #{library_config[:name]}
            @#{library_config[:name]} ||= begin
              obj = Object.new.extend(#{lib_module})
              def obj.commands
                #{lib_module}.instance_methods
              end
              private
              def obj.method_missing(method, *args, &block)
                Iam.base_object.send(method, *args, &block)
              end
              obj
            end
          end
        ]
        Manager.add_object_command(library_config[:name])
      end

      def safe_require(lib)
        begin
          require lib
        rescue LoadError
          false
        end
      end

      # attributes: name, type, loaded, commands
      def create(name, lib_hash={})
        library_obj = library_config(name).merge(lib_hash)
        set_library_commands(library_obj)
        reset_library_config
        new(library_obj)
      end

      def set_library_commands(library_obj)
        aliases = library_obj[:commands].map {|e|
          config[:commands][e][:alias] rescue nil
        }.compact
        library_obj[:commands] -= aliases
        library_obj[:commands].delete(library_obj[:name]) if library_obj[:object_command]
      end
    end
  end
end
