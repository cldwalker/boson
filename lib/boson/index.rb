require 'digest/md5'
module Boson
  module Index
    extend self
    attr_reader :libraries, :commands

    def read_and_transfer(ignored_libraries=[])
      read
      existing_libraries = (Boson.libraries.map {|e| e.name} + ignored_libraries).uniq
      Boson.libraries += @libraries.select {|e| !existing_libraries.include?(e.name)}
      existing_commands = Boson.commands.map {|e| e.name} #td: consider namespace
      Boson.commands += @commands.select {|e| !existing_commands.include?(e.name) && !ignored_libraries.include?(e.lib)}
    end

    def update(options={})
      options[:all] = true if !exists? && !options.key?(:all)
      libraries_to_update = options[:all] ? Runner.all_libraries : changed_libraries
      read_and_transfer(libraries_to_update)
      if options[:verbose]
        puts options[:all] ? "Generating index for all #{libraries_to_update.size} libraries. Patience ... is a bitch" :
          (libraries_to_update.empty? ? "No libraries indexed" :
          "Indexing the following libraries: #{libraries_to_update.join(', ')}")
      end
      Library.load(libraries_to_update, options.merge(:index=>true))
      write
    end

    def exists?
      File.exists? marshal_file
    end

    def find_library(command, subcommand=nil)
      read
      find_lambda = subcommand ? lambda {|e| method(:is_namespace_command).call(e, command, subcommand) } :
        lambda {|e| [e.name, e.alias].include?(command)}
      if (found = @commands.find(&find_lambda))
        (found.lib == 'namespace') ? find_namespace_library(found.name) : found.lib
      end
    end

    def write
      marshal_string = Marshal.dump [Boson.libraries.map {|e| e.dup.marshalize }, Boson.commands, latest_hashes]
      File.open(marshal_file, 'w') {|f| f.write marshal_string }
    end

    def read
      return if @read
      @libraries, @commands, @lib_hashes = exists? ? Marshal.load(File.read(marshal_file)) : [[], [], {}]
      @read = true
    end

    def marshal_file
      File.join(Boson.repo.config_dir, 'index.marshal')
    end

    def is_namespace_command(current_command, command, subcommand)
      [current_command.name, current_command.alias].include?(subcommand) &&
      (namespace_command = @commands.find {|f| [f.name, f.alias].include?(command) && f.lib == 'namespace'}) &&
      current_command.lib[/\w+$/] == namespace_command.name
    end

    def find_namespace_library(name)
      (namespace_command = @commands.find {|f| [f.name, f.alias].include?(name) && f.lib == 'namespace'}) &&
        (lib = @libraries.find {|e| e.namespace_command == namespace_command.name }) && lib.name
    end

    def changed_libraries
      read
      latest_hashes.select {|lib, hash| @lib_hashes[lib] != hash}.map {|e| e[0]}
    end

    def latest_hashes
      Runner.all_libraries.inject({}) {|h, e|
        lib_file = FileLibrary.library_file(e, Boson.repo.dir)
        h[e] = Digest::MD5.hexdigest(File.read(lib_file)) if File.exists?(lib_file)
        h
      }
    end
  end
end