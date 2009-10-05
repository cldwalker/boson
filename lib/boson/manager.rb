module Boson
  class LoaderError < StandardError; end
  class LoadingDependencyError < LoaderError; end
  class AppendFeaturesFalseError < StandardError; end

  class Manager
    class <<self
      # ==== Options:
      # [:verbose] Prints the status of each library as its loaded. Default is false.
      def load(libraries, options={})
        libraries = [libraries] unless libraries.is_a?(Array)
        libraries.map {|e|
          (@library = load_once(e, options)) ? after_load : false
        }.all?
      end

      def reload_library(source, options={})
        if (lib = Boson.library(source))
          if lib.loaded
            command_size = Boson.commands.size
            @options = options
            if (result = rescue_load_action(lib.name, :reload) { lib.reload })
              after_reload(lib)
              puts "Reloaded library #{source}: Added #{Boson.commands.size - command_size} commands" if options[:verbose]
            end
            result
          else
            puts "Library hasn't been loaded yet. Loading library #{source}..." if options[:verbose]
            load(source, options)
          end
        else
          puts "Library #{source} doesn't exist." if options[:verbose]
          false
        end
      end

      #:stopdoc:
      def add_library(lib)
        Boson.libraries.delete(Boson.library(lib.name))
        Boson.libraries << lib
      end

      def loaded?(lib_name)
        ((lib = Boson.library(lib_name)) && lib.loaded) ? true : false
      end

      def rescue_load_action(library, load_method)
        yield
      rescue AppendFeaturesFalseError
      rescue LoaderError=>e
        FileLibrary.reset_file_cache(library.to_s)
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{e.message}"
      rescue Exception=>e
        FileLibrary.reset_file_cache(library.to_s)
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{$!}" + "\n" +
          e.backtrace.slice(0,3).join("\n")
      ensure
        Inspector.remove_meta_methods if Inspector.enabled
      end

      def print_error_message(message)
        $stderr.puts message if !@options[:index] || (@options[:index] && @options[:verbose])
      end

      def load_once(source, options={})
        @options = options
        rescue_load_action(source, :load) do
          lib = loader_create(source)
          if loaded?(lib.name)
            $stderr.puts "Library #{lib.name} already exists" if options[:verbose] && !options[:dependency]
            false
          else
            if lib.load { load_dependencies(lib, options) }
              lib
            else
              $stderr.puts "Unable to load library #{lib.name}." if !options[:dependency]
              false
            end
          end
        end
      end

      def lib_dependencies
        @lib_dependencies ||= {}
      end

      def load_dependencies(lib, options={})
        lib_dependencies[lib] = (lib.dependencies || []).map do |e|
          next if loaded?(e)
          load_once(e, options.merge(:dependency=>true)) ||
            raise(LoadingDependencyError, "Can't load dependency #{e}")
        end.compact
      end

      def loader_create(source)
        lib_class = Library.handle_blocks.find {|k,v| v.call(source) } or raise(LoaderError, "Library #{source} not found.")
        lib_class[0].new(:name=>source, :index=>@options[:index])
      end

      def after_load
        create_commands(@library)
        add_library(@library)
        puts "Loaded library #{@library.name}" if @options[:verbose]
        (lib_dependencies[@library] || []).each do |e|
          create_commands(e)
          add_library(e)
          puts "Loaded library dependency #{e.name}" if @options[:verbose]
        end
        true
      end

      def after_reload(lib)
        Boson.commands.delete_if {|e| e.lib == lib.name } if lib.new_module
        create_commands(lib, lib.new_commands)
      end

      def before_create_commands(lib)
        if lib.is_a?(FileLibrary) && lib.module
          Inspector.add_scraped_data(lib.module, lib.commands_hash, lib.library_file)
        end
      end

      def create_commands(lib, commands=lib.commands)
        if lib.except
          commands -= lib.except
          lib.except.each {|e| lib.namespace_object.instance_eval("class<<self;self;end").send :undef_method, e }
        end
        before_create_commands(lib)
        commands.each {|e| Boson.commands << Command.create(e, lib)}
        create_command_aliases(lib, commands) if commands.size > 0 && !lib.no_alias_creation
        create_option_commands(lib, commands)
      end

      def create_option_commands(lib, commands)
        option_commands = lib.command_objects(commands).select {|e| e.option_command? }
        accepted, rejected = option_commands.partition {|e| e.args(lib) || e.arg_size }
        if @options[:verbose] && rejected.size > 0
          puts "Following commands cannot have options until their arguments are configured: " +
            rejected.map {|e| e.name}.join(', ')
        end
        accepted.each {|cmd| Scientist.create_option_command(lib.namespace_object, cmd) }
      end

      def create_command_aliases(lib, commands)
        lib.module ? prep_and_create_instance_aliases(commands, lib.module) : check_for_uncreated_aliases(lib, commands)
      end

      def prep_and_create_instance_aliases(commands, lib_module)
        aliases_hash = {}
        select_commands = Boson.commands.select {|e| commands.include?(e.name)}
        select_commands.each do |e|
          if e.alias
            aliases_hash[lib_module.to_s] ||= {}
            aliases_hash[lib_module.to_s][e.name] = e.alias
          end
        end
        create_instance_aliases(aliases_hash)
      end

      def create_instance_aliases(aliases_hash)
        Alias.manager.create_aliases(:instance_method, aliases_hash)
      end

      def create_class_aliases(mod, class_commands)
        Alias.manager.create_aliases(:any_to_instance_method, mod.to_s=>class_commands.invert)
      end

      def check_for_uncreated_aliases(lib, commands)
        return if lib.is_a?(GemLibrary)
        if (found_commands = Boson.commands.select {|e| commands.include?(e.name)}) && found_commands.find {|e| e.alias }
          $stderr.puts "No aliases created for library #{lib.name} because it has no module"
        end
      end
    end
  end
end