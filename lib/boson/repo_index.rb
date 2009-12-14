require 'digest/md5'
module Boson
  # This class provides an index for commands and libraries of a given a Repo.
  # When this index updates, it detects library files whose md5 hash have changed and reindexes them.
  # The index is stored with Marshal at config/index.marshal (relative to a Repo's root directory). 
  # Since the index is marshaled, putting lambdas/procs in it will break it.If an index gets corrupted,
  # simply delete it and next time Boson needs it, the index will be recreated.
  
  class RepoIndex
    attr_reader :libraries, :commands, :repo
    def initialize(repo)
      @repo = repo
    end

    # Updates the index.
    def update(options={})
      libraries_to_update = !exists? ? repo.all_libraries : options[:libraries] || changed_libraries
      read_and_transfer(libraries_to_update)
      if options[:verbose]
        puts !exists? ? "Generating index for all #{libraries_to_update.size} libraries. Patience ... is a bitch" :
          (libraries_to_update.empty? ? "No libraries indexed" :
          "Indexing the following libraries: #{libraries_to_update.join(', ')}")
      end
      Manager.failed_libraries = []
      unless libraries_to_update.empty?
        Manager.load(libraries_to_update, options.merge(:index=>true))
        unless Manager.failed_libraries.empty?
          $stderr.puts("Error: These libraries failed to load while indexing: #{Manager.failed_libraries.join(', ')}")
        end
      end
      write(Manager.failed_libraries)
    end

    # Reads and initializes index.
    def read
      return if @read
      @libraries, @commands, @lib_hashes = exists? ? Marshal.load(File.read(marshal_file)) : [[], [], {}]
      delete_stale_libraries_and_commands
      set_command_namespaces
      @read = true
    end

    # Writes/saves current index to config/index.marshal.
    def write(failed_libraries=[])
      latest = latest_hashes
      failed_libraries.each {|e| latest.delete(e) }
      save_marshal_index Marshal.dump([Boson.libraries, Boson.commands, latest])
    end

    #:stopdoc:
    def read_and_transfer(ignored_libraries=[])
      read
      existing_libraries = (Boson.libraries.map {|e| e.name} + ignored_libraries).uniq
      libraries_to_add = @libraries.select {|e| !existing_libraries.include?(e.name)}
      Boson.libraries += libraries_to_add
      # depends on saved commands being correctly associated with saved libraries
      Boson.commands += libraries_to_add.map {|e| e.command_objects(e.commands, @commands) }.flatten
    end

    def exists?
      File.exists? marshal_file
    end

    def save_marshal_index(marshal_string)
      File.open(marshal_file, 'w') {|f| f.write marshal_string }
    end

    def delete_stale_libraries_and_commands
      cached_libraries = @lib_hashes.keys
      libs_to_delete = @libraries.select {|e| !cached_libraries.include?(e.name) && e.is_a?(FileLibrary) }
      names_to_delete = libs_to_delete.map {|e| e.name }
      libs_to_delete.each {|e| @libraries.delete(e) }
      @commands.delete_if {|e| names_to_delete.include? e.lib }
    end

    # set namespaces for commands
    def set_command_namespaces
      lib_commands = @commands.inject({}) {|t,e| (t[e.lib] ||= []) << e; t }
      namespace_libs = @libraries.select {|e| e.namespace(e.indexed_namespace) }
      namespace_libs.each {|lib|
        (lib_commands[lib.name] || []).each {|e| e.namespace = lib.namespace }
      }
    end

    def namespaces
      nsps = @libraries.map {|e| e.namespace }.compact
      nsps.delete(false)
      nsps
    end

    def all_main_methods
      @commands.reject {|e| e.namespace }.map {|e| [e.name, e.alias]}.flatten.compact + namespaces
    end

    def marshal_file
      File.join(repo.config_dir, 'index.marshal')
    end

    def find_library(command, object=false)
      read
      namespace_command = command.split('.')[0]
      if (lib = @libraries.find {|e| e.namespace == namespace_command })
        object ? lib : lib.name
      elsif (cmd = Command.find(command, @commands))
        object ? @libraries.find {|e| e.name == cmd.lib} : cmd.lib
      end
    end

    def changed_libraries
      read
      latest_hashes.select {|lib, hash| @lib_hashes[lib] != hash}.map {|e| e[0]}
    end

    def latest_hashes
      repo.all_libraries.inject({}) {|h, e|
        lib_file = FileLibrary.library_file(e, repo.dir)
        h[e] = Digest::MD5.hexdigest(File.read(lib_file)) if File.exists?(lib_file)
        h
      }
    end
    #:startdoc:
  end
end