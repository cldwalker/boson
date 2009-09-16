module Boson
  class FileLibrary < Library
    def self.library_file(library, dir)
      File.join(Repo.commands_dir(dir), library + ".rb")
    end

    def self.matched_repo; @repo; end

    def self.read_library_file(file, reload=false)
      @file_cache ||= {}
      @file_cache[file] = File.read(file) if (!@file_cache.has_key?(file) || reload)
      @file_cache[file]
    end

    def self.reset_file_cache(name=nil)
      if name && @file_cache
        #td: tia other repos
        @file_cache.delete(library_file(name, Boson.repo.dir))
      else
        @file_cache = nil
      end
    end

    handles {|source|
      @repo = Boson.repos.find {|e|
        File.exists? library_file(source.to_s, e.dir)
      }
      !!@repo
    }

    def library_file
      self.class.library_file(@name, @repo_dir)
    end

    def set_repo
      self.class.matched_repo
    end

    def load_source(reload=false)
      library_string = self.class.read_library_file(library_file, reload)
      Inspector.add_meta_methods
      Commands.module_eval(library_string, library_file)
      Inspector.remove_meta_methods
    end

    def load_source_and_set_module
      detected = detect_additions(:modules=>true) { load_source }
      @module = determine_lib_module(detected[:modules]) unless @module
    end

    def reload_source_and_set_module
      detected = detect_additions(:modules=>true) { load_source(true) }
      if (@new_module = !detected[:modules].empty?)
        @commands = []
        @module = determine_lib_module(detected[:modules])
      end
    end

    def determine_lib_module(detected_modules)
      case detected_modules.size
      when 1 then lib_module = detected_modules[0]
      when 0 then raise LoaderError, "Can't detect module. Make sure at least one module is defined in the library."
      else
        unless ((lib_module = Util.constantize("boson/commands/#{@name}")) && lib_module.to_s[/^Boson::Commands/])
          raise LoaderError, "Can't detect module. Specify a module in this library's config."
        end
      end
      lib_module
    end

    def before_create_commands
      if @module
        add_command_descriptions(commands) if @module.instance_variable_defined?(:@_descriptions)
        add_command_options if @module.instance_variable_defined?(:@_options)
        add_comment_metadata if @module.instance_variable_defined?(:@_method_locations)
        add_command_args if @module.instance_variable_defined?(:@_method_args)
      end
    end

    def add_command_args
      @module.instance_variable_get(:@_method_args).each do |cmd, args|
        if no_command_config_for(cmd, :args)
          (@commands_hash[cmd] ||= {})[:args] = args
        end
      end
    end

    def add_command_options
      @module.instance_variable_get(:@_options).each do |cmd, options|
        if no_command_config_for(cmd, :options)
          (@commands_hash[cmd] ||= {})[:options] = options
        end
      end
    end

    def add_comment_metadata
      @module.instance_variable_get(:@_method_locations).each do |cmd, (file, lineno)|
        if file == library_file
          if no_command_config_for(cmd, :description)
            if (description = Inspector.description_from_file(self.class.read_library_file(file), lineno))
              (@commands_hash[cmd] ||= {})[:description] = description
            end
          end
          if no_command_config_for(cmd, :options)
            if (options = Inspector.options_from_file(self.class.read_library_file(file), lineno))
              (@commands_hash[cmd] ||= {})[:options] = options
            end
          end
        end
      end
    end

    def add_command_descriptions(commands)
      @module.instance_variable_get(:@_descriptions).each do |cmd, description|
        if no_command_config_for(cmd, :description)
          (@commands_hash[cmd] ||= {})[:description] = description
        end
      end
    end

    def no_command_config_for(cmd, attribute)
      !@commands_hash[cmd] || (@commands_hash[cmd] && !@commands_hash[cmd].key?(attribute))
    end
  end
end