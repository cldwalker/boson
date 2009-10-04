module Boson
  class Manager
    class <<self
      def load(libraries, options={})
        libraries.map {|e| load_library(e, options) }.all?
      end

      def create(libraries, attributes={})
        libraries.map {|e| lib = Library.new({:name=>e}.update(attributes)); add_library(lib); lib }
      end

      # ==== Options:
      # [:verbose] Prints the status of each library as its loaded. Default is false.
      def load_library(source, options={})
        (lib = load_once(source, options)) ? lib.after_load(options) : false
      end

      def reload_library(source, options={})
        if (lib = Boson.library(source))
          if lib.loaded
            command_size = Boson.commands.size
            if (result = rescue_load_action(lib.name, :reload, options) { lib.reload })
              lib.after_reload
              puts "Reloaded library #{source}: Added #{Boson.commands.size - command_size} commands" if options[:verbose]
            end
            result
          else
            puts "Library hasn't been loaded yet. Loading library #{source}..." if options[:verbose]
            load_library(source, options)
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

      def rescue_load_action(library, load_method, options={})
        yield
      rescue AppendFeaturesFalseError
      rescue LoaderError=>e
        FileLibrary.reset_file_cache(library.to_s)
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{e.message}", options
      rescue Exception=>e
        FileLibrary.reset_file_cache(library.to_s)
        print_error_message "Unable to #{load_method} library #{library}. Reason: #{$!}" + "\n" +
          e.backtrace.slice(0,3).join("\n"), options
      ensure
        Inspector.remove_meta_methods if Inspector.enabled
      end

      def print_error_message(message, options)
        $stderr.puts message if !options[:index] || (options[:index] && options[:verbose])
      end

      def load_once(source, options={})
        rescue_load_action(source, :load, options) do
          lib = loader_create(source, options)
          if loaded?(lib.name)
            $stderr.puts "Library #{lib.name} already exists" if options[:verbose] && !options[:dependency]
            false
          else
            if lib.load
              lib
            else
              $stderr.puts "Unable to load library #{lib.name}." if !options[:dependency]
              false
            end
          end
        end
      end

      def loader_create(source, options={})
        lib_class = Library.handle_blocks.find {|k,v| v.call(source) } or raise(LoaderError, "Library #{source} not found.")
        lib_class[0].new(:name=>source, :options=>options)
      end
    end
  end
end