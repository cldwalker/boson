module Boson
  class Library
    include Loader
    class <<self
      attr_accessor :handle_blocks
      def handles(&block)
        (Library.handle_blocks ||= []) << [self,block]
      end
      #:startdoc:
    end

    ATTRIBUTES = [:gems, :dependencies, :commands, :loaded, :module, :name, :namespace]
    attr_reader *(ATTRIBUTES + [:commands_hash, :library_file, :object_namespace])
    attr_reader :created_dependencies, :except, :no_alias_creation, :options, :new_module, :new_commands
    attr_writer :namespace
    def initialize(hash)
      @name = set_name hash.delete(:name)
      @options = hash.delete(:options) || {}
      @loaded = false
      repo = set_repo
      @repo_dir = repo.dir
      @commands_hash = {}
      @commands = []
      set_config (repo.config[:libraries][@name] || {}).merge(hash)
      @commands_hash = repo.config[:commands].merge @commands_hash
      set_command_aliases(repo.config[:command_aliases])
      @namespace = true if Boson.repo.config[:auto_namespace] && @namespace.nil? &&
        !Boson::Runner.default_libraries.include?(@module)
      @namespace = clean_name if @namespace
    end

    # handles names under directories
    def clean_name
      @name[/\w+$/]
    end

    def set_name(name)
      name.to_s or raise ArgumentError, "New library missing required key :name"
    end

    def set_config(config)
      if (commands = config.delete(:commands))
        if commands.is_a?(Array)
          @commands += commands
        elsif commands.is_a?(Hash)
          @commands_hash = Util.recursive_hash_merge commands, @commands_hash
        end
      end
      set_command_aliases config.delete(:command_aliases) if config[:command_aliases]
      set_attributes config, true
    end

    def set_command_aliases(command_aliases)
      (command_aliases || {}).each do |cmd, cmd_alias|
        @commands_hash[cmd] ||= {}
        @commands_hash[cmd][:alias] ||= cmd_alias
      end
    end

    def set_repo
      Boson.repo
    end

    def set_attributes(hash, force=false)
      hash.each {|k,v| instance_variable_set("@#{k}", v) if instance_variable_get("@#{k}").nil? || force }
    end

    def command_objects(names)
      Boson.commands.select {|e| names.include?(e.name) && e.lib == self.name }
    end

    def library_type
      str = self.class.to_s[/::(\w+)Library$/, 1] || 'library'
      str.downcase.to_sym
    end

    def namespace_object
      @namespace_object ||= @namespace ? Boson.invoke(@namespace) : Boson.main_object
    end

    def marshal_dump
      [@name, @commands, @gems, @module.to_s, @repo_dir]
    end

    def marshal_load(ary)
      @name, @commands, @gems, @module, @repo_dir = ary
    end
  end
end