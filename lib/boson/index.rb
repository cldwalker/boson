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
      Library.load(libraries_to_update, options.merge(:index=>true)) unless libraries_to_update.empty?
      write
    end

    def exists?
      File.exists? marshal_file
    end

    def write
      save_marshal_index Marshal.dump([Boson.libraries, Boson.commands, latest_hashes])
    end

    def save_marshal_index(marshal_string)
      File.open(marshal_file, 'w') {|f| f.write marshal_string }
    end

    def read
      return if @read
      @libraries, @commands, @lib_hashes = exists? ? Marshal.load(File.read(marshal_file)) : [[], [], {}]
      set_namespaces
      @read = true
    end

    def set_namespaces
      namespace_libs = Boson.repo.config[:auto_namespace] ? @libraries.map {|e| [e.name, {:namespace=>true}]} :
        Boson.repo.config[:libraries].select {|k,v| v && v[:namespace] }
      namespace_libs.each {|name, hash|
        if (lib = @libraries.find {|l| l.name == name})
          lib.namespace = (hash[:namespace] == true) ? lib.clean_name : hash[:namespace]
        end
      }
      @namespaces = @libraries.map {|e| e.namespace}.compact
    end

    def marshal_file
      File.join(Boson.repo.config_dir, 'index.marshal')
    end

    def find_library(command)
      read
      namespace_command = command.split('.')[0]
      if (lib = @libraries.find {|e| e.namespace == namespace_command })
        lib.name
      elsif (found = Command.find(command, @commands))
        found.lib
      end
    end

    # def find_namespace_library(name)
    #   (namespace_command = @commands.find {|f| [f.name, f.alias].include?(name) && f.lib == 'namespace'}) &&
    #     (lib = @libraries.find {|e| e.namespace == namespace_command.name }) && lib.name
    #   # @commands.find {|f| f.library && f.library.namespace == name}
    # end

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