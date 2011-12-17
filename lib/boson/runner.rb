module Boson
  # Base class for runners.
  class Runner
    DEFAULT_LIBRARIES = [Boson::Commands::Core]

    module API
      def start(*)
        load_rc
      end
    end

    class<<self
      include API
      attr_accessor :debug

      # Enables view, adds local load path and loads default_libraries
      def init
        View.enable
        add_load_path
        Manager.load default_libraries, load_options
      end

      def load_rc
        rc = ENV['BOSONRC'] || '~/.bosonrc'
        load(rc) if !rc.empty? && File.exists?(File.expand_path(rc))
      rescue StandardError, SyntaxError, LoadError => err
        warn "Error while loading #{rc}:\n"+
          "#{err.class}: #{err.message}\n    #{err.backtrace.join("\n    ")}"
      end

      # Libraries that come with Boson
      def default_libraries
        Boson.repos.map {|e| e.config[:defaults] || [] }.flatten + DEFAULT_LIBRARIES
      end

      # Libraries detected in repositories
      def detected_libraries
        Boson.repos.map {|e| e.detected_libraries }.flatten.uniq
      end

      # Libraries specified in config files and detected_libraries
      def all_libraries
        Boson.repos.map {|e| e.all_libraries }.flatten.uniq
      end

      # Returns true if commands are being executed from a non-ruby shell i.e. bash. Returns false if
      # in a ruby shell i.e. irb.
      def in_shell?
        !!@in_shell
      end

      # Returns true if in commandline with verbose flag or if set explicitly. Useful in plugins.
      def verbose?
        @verbose.nil? ? Boson.const_defined?(:BinRunner) && BinRunner.options[:verbose] : @verbose
      end

      #:stopdoc:
      def verbose=(val)
        @verbose = val
      end

      def in_shell=(val)
        @in_shell = val
      end

      def add_load_path
        Boson.repos.each {|repo|
          if repo.config[:add_load_path] || File.exists?(File.join(repo.dir, 'lib'))
            $: <<  File.join(repo.dir, 'lib') unless $:.include? File.expand_path(File.join(repo.dir, 'lib'))
          end
        }
      end

      def load_options
        {:verbose=>@options[:verbose]}
      end

      def autoload_command(cmd, opts={:verbose=>verbose?})
        Index.read
        (lib = Index.find_library(cmd)) && Manager.load(lib, opts)
        lib
      end

      def define_autoloader
        class << ::Boson.main_object
          def method_missing(method, *args, &block)
            if Runner.autoload_command(method.to_s)
              send(method, *args, &block) if respond_to?(method)
            else
              super
            end
          end
        end
      end
      #:startdoc:
    end
  end
end
