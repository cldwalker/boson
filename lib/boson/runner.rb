module Boson
  class Runner
    class<<self
      def init
        Hirb.enable(:config_file=>File.join(Boson.config_dir, 'hirb.yml'))
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

      def unalias_libraries(libs)
        libs ? libs.split(/\s*,\s*/) : []
      end

      def marshal_file
        File.join(Boson.config_dir, 'commands.db')
      end

      def marshal_write
        marshal_string = Marshal.dump [Boson.libraries.map {|e| e.dup.marshalize }, Boson.commands]
        File.open(marshal_file, 'w') {|f| f.write marshal_string }
      end

      def marshal_read
        new_libraries, new_commands = Marshal.load(File.read(marshal_file))
        existing_libraries = Boson.libraries.map {|e| e.name}
        Boson.libraries += new_libraries.select {|e| !existing_libraries.include?(e.name)}
        existing_commands = Boson.commands.map {|e| e.name}
        Boson.commands += new_commands.select {|e| !existing_commands.include?(e.name)}
      end

      def index_commands(options={})
        Library.load(all_libraries, options.merge(:index=>true))
        marshal_write
      end
    end
  end
end