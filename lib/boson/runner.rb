module Boson
  # Base class for runners.
  class Runner
    class<<self
      # Enables view, adds local load path and loads default_libraries
      def init
        View.enable
        add_load_path
        Manager.load default_libraries, load_options
      end

      # Libraries that come with Boson
      def default_libraries
        [Boson::Commands::Core, Boson::Commands::WebCore] + (Boson.repo.config[:defaults] || [])
      end

      # Libraries detected in repositories
      def detected_libraries
        Boson.repos.map {|repo| Dir[File.join(repo.commands_dir, '**/*.rb')].
          map {|e| e.gsub(/.*commands\//,'').gsub('.rb','') } }.flatten
      end

      # Libraries specified in config files and detected_libraries
      def all_libraries
        (detected_libraries + Boson.repos.map {|e| e.config[:libraries].keys}.flatten).uniq
      end

      #:stopdoc:
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

      def define_autoloader
        class << ::Boson.main_object
          def method_missing(method, *args, &block)
            Boson::Index.read
            if lib = Boson::Index.find_library(method.to_s)
              Boson::Manager.load lib, :verbose=>true
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