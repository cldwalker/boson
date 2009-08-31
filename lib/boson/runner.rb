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

      def marshal_file
        File.join(Boson.config_dir, 'commands.db')
      end

      def marshal_write
        marshal_string = Marshal.dump Boson.libraries.map {|e| [e.name, e.all_commands] }
        File.open(marshal_file, 'w') {|f| f.write marshal_string }
      end

      def marshal_read
        if File.exists?(marshal_file)
          Marshal.load(File.read(marshal_file))
        end
      end

      def index
        @index ||= marshal_read
      end

      def index_commands
        Library.load([Boson::Commands::Namespace] + all_libraries, :index=>true)
        marshal_write
      end
    end
  end
end