module Boson
  # This library loads a file in the commands subdirectory of a Boson::Repo. This library looks for files
  # in repositories in the order given by Boson.repos.
  # TODO: explain file format, modules, inspectors
  class FileLibrary < Library
    #:stopdoc:
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
      Inspector.enable
      Commands.module_eval(library_string, library_file)
      Inspector.disable
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
    #:startdoc:
  end
end