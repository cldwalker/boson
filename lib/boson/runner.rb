module Boson
  class Runner
    class<<self
      def init(options={})
        Hirb.enable(:config_file=>File.join(Boson.config_dir, 'hirb.yml'))
        add_load_path
      end

      def add_load_path
        if Boson.config[:add_load_path] || File.exists?(File.join(Boson.dir, 'lib'))
          $: <<  File.join(Boson.dir, 'lib') unless $:.include? File.expand_path(File.join(Boson.dir, 'lib'))
        end
      end

      def boson_libraries
        [Boson::Commands::Core, Boson::Commands::Namespace]
      end

      def detected_libraries
        Dir[File.join(Boson.commands_dir, '**/*.rb')].map {|e| e.gsub(/.*commands\//,'').gsub('.rb','') }
      end

      def all_libraries
        (detected_libraries + Boson.config[:libraries].keys).uniq
      end
    end
  end
end