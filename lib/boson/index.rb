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

    def marshal_read
      new_libraries, new_commands = Marshal.load(File.read(marshal_file))
      existing_libraries = Boson.libraries.map {|e| e.name}
      Boson.libraries += new_libraries.select {|e| !existing_libraries.include?(e.name)}
      existing_commands = Boson.commands.map {|e| e.name}
      Boson.commands += new_commands.select {|e| !existing_commands.include?(e.name)}
    end

    def index_commands(options={})
      Library.load(Runner.all_libraries, options.merge(:index=>true))
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
  end
end