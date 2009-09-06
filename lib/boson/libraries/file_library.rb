module Boson
  class FileLibrary < Library
    def self.library_file(library, repo=Boson.repo)
      File.join(repo.commands_dir, library + ".rb")
    end

    def self.matched_repo; @repo; end

    handles {|source|
      @repo = Boson.repos.find {|e|
        File.exists? library_file(source.to_s, e)
      }
      !!@repo
    }

    def library_file
      self.class.library_file(@name, @repo)
    end

    def initialize(hash)
      super
      @repo = self.class.matched_repo
    end

    def load_init
      super
      @no_module_eval ||= !!@module
    end

    def load_source
      if @no_module_eval
        Kernel.load library_file
      else
        library_string = File.read(library_file)
        Commands.module_eval(library_string, library_file)
      end
    end

    def load_source_and_set_module
      detected = detect_additions(:modules=>true) { load_source }
      @module = determine_lib_module(detected[:modules]) unless @module
    end

    def reload_source_and_set_module
      detected = detect_additions(:modules=>true) { load_source }
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
  end
end