require 'digest/md5'
module Boson
  # This class is used by BinRunner to index/store all of Boson's commands and libraries. When this index updates,
  # it detects library files whose md5 hash have changed and reindexes them. The index is stored with Marshal
  # at ~/.boson/config/index.marshal. Since the index is marshaled, putting lambdas/procs in it will break it.
  # If your index gets corrupted, simply delete it and next time Boson needs it, the index will be recreated.
  module Index
    extend self
    attr_reader :libraries, :commands

    # Updates the index.
    def update(options={})
      options[:all] = true if !exists? && !options.key?(:all)
      libraries_to_update = options[:all] ? Runner.all_libraries : changed_libraries
      read_and_transfer(libraries_to_update)
      if options[:verbose]
        puts options[:all] ? "Generating index for all #{libraries_to_update.size} libraries. Patience ... is a bitch" :
          (libraries_to_update.empty? ? "No libraries indexed" :
          "Indexing the following libraries: #{libraries_to_update.join(', ')}")
      end
      unless libraries_to_update.empty?
        Manager.load(libraries_to_update, options) || $stderr.puts("Error: One of these libraries failed" +
          " to load while indexing: #{libraries_to_update.join(', ')}")
      end
      write
    end

    # Reads and initializes index.
    def read
      return if @read
      @libraries, @commands, @lib_hashes = exists? ? Marshal.load(File.read(marshal_file)) : [[], [], {}]
      delete_stale_libraries_and_commands
      set_latest_namespaces
      @read = true
    end

    # Writes/saves current index to config/index.marshal.
    def write
      save_marshal_index Marshal.dump([Boson.libraries, Boson.commands, latest_hashes])
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

    # get latest namespaces from config files
    def set_latest_namespaces
      namespace_libs = Boson.repo.config[:auto_namespace] ? @libraries.map {|e| [e.name, {:namespace=>true}]} :
        Boson.repo.config[:libraries].select {|k,v| v && v[:namespace] }
      lib_commands = @commands.inject({}) {|t,e| (t[e.lib] ||= []) << e; t }
      namespace_libs.each {|name, hash|
        if (lib = @libraries.find {|l| l.name == name})
          lib.namespace = (hash[:namespace] == true) ? lib.clean_name : hash[:namespace]
          (lib_commands[lib.name] || []).each {|e| e.namespace = lib.namespace }
        end
      }
    end

    def namespaces
      @libraries.map {|e| e.namespace }.compact
    end

    def all_main_methods
      @commands.reject {|e| e.namespace }.map {|e| [e.name, e.alias]}.flatten.compact + namespaces
    end

    def marshal_file
      File.join(Boson.repo.config_dir, 'index.marshal')
    end

    def find_library(command)
      read
      namespace_command = command.split('.')[0]
      if (lib = @libraries.find {|e| e.namespace == namespace_command })
        lib.name
      elsif (cmd = Command.find(command, @commands))
        cmd.lib
      end
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
    #:startdoc:
  end
end