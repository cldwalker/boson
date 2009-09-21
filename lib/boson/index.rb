require 'digest/md5'
module Boson
  module Index
    extend self
    def marshal_file
      File.join(Boson.repo.config_dir, 'commands.db')
    end

    def marshal_write
      marshal_string = Marshal.dump [Boson.libraries.map {|e| e.dup.marshalize }, Boson.commands]
      File.open(marshal_file, 'w') {|f| f.write marshal_string }
    end

    def marshal_read(ignored_libraries=[])
      new_libraries, new_commands = Marshal.load(File.read(marshal_file))
      existing_libraries = (Boson.libraries.map {|e| e.name} + ignored_libraries).uniq
      Boson.libraries += new_libraries.select {|e| !existing_libraries.include?(e.name)}
      existing_commands = Boson.commands.map {|e| e.name}
      Boson.commands += new_commands.select {|e| !existing_commands.include?(e.name)}
    end

    def index_commands(options={})
      index_libraries = options[:index_all] ? Runner.all_libraries : changed_libraries
      marshal_read(index_libraries)
      Library.load(index_libraries, options.merge(:index=>true))
      write_hashes
      marshal_write
    end

    def find_library(command, subcommand)
      @command, @subcommand = command, subcommand
      find_lambda = subcommand ? method(:is_namespace_command) : lambda {|e| [e.name, e.alias].include?(@command)}
      if !BinRunner.command_defined?(command) && (found = Boson.commands.find(&find_lambda))
        found.lib
      end
    end

    def is_namespace_command(cmd)
      [cmd.name, cmd.alias].include?(@subcommand) &&
      (command = Boson.commands.find {|f| f.name == @command && f.lib == 'namespace'} || Boson.command(@command, :alias)) &&
      cmd.lib[/\w+$/] == command.name
    end

    def load(force=false)
      if !File.exists?(marshal_file) || force
        puts "Indexing commands ..."
        index_commands(BinRunner.load_options)
      else
        marshal_read
      end
    end

    def write_hashes
      File.open(hash_file, 'w') {|f| f.write(latest_hashes.to_yaml)}
    end

    def changed_libraries
      old_hashes = YAML::load_file hash_file rescue {}
      latest_hashes.select {|lib, hash| old_hashes[lib] != hash}.map {|e| e[0]}
    end

    def hash_file
      hash_file = File.join(Boson.repo.config_dir, "library_hashes.yml")
    end

    def latest_hashes
      Boson::Runner.all_libraries.inject({}) {|h, e|
        lib_file = Boson::FileLibrary.library_file(e, Boson.repo.dir)
        h[e] = Digest::MD5.hexdigest(File.read(lib_file)) if File.exists?(lib_file)
        h
      }
    end
  end
end