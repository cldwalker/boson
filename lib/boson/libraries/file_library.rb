module Boson
  class FileLibrary < Library
    handles {|source| File.exists?(library_file(source.to_s)) }

    def load_init
      super
      @no_module_eval ||= !!@module
    end

    def load_source
      if @no_module_eval
        Kernel.load self.class.library_file(@name)
      else
        library_string = File.read(self.class.library_file(@name))
        Commands.module_eval(library_string, self.class.library_file(@name))
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