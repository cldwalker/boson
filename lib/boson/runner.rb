module Boson
  class Runner
    class<<self
      def init
        Hirb.enable(:config_file=>File.join(Boson.repo.config_dir, 'hirb.yml'))
        add_load_path
      end

      def add_load_path
        Boson.repos.each {|repo|
          if repo.config[:add_load_path] || File.exists?(File.join(repo.dir, 'lib'))
            $: <<  File.join(repo.dir, 'lib') unless $:.include? File.expand_path(File.join(repo.dir, 'lib'))
          end
        }
      end

      def boson_libraries
        [Boson::Commands::Core, Boson::Commands::WebCore, Boson::Commands::Namespace, Boson::Commands::IrbCore]
      end

      def detected_libraries
        Boson.repos.map {|repo| Dir[File.join(repo.commands_dir, '**/*.rb')].
          map {|e| e.gsub(/.*commands\//,'').gsub('.rb','') } }.flatten
      end

      def all_libraries
        (detected_libraries + Boson.repos.map {|e| e.config[:libraries].keys}.flatten).uniq
      end
    end
  end
end