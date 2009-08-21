module Boson
  class ModuleLibrary < Library
    handles {|name| name.is_a?(Module) }

    def reload; end

    def create_loader
      underscore_lib = @source.to_s[/^Boson::Libraries/] ? @source.to_s.split('::')[-1] : @source
      super.merge(:module=>@source, :name=>Util.underscore(underscore_lib))
    end
  end

  class FileLibrary < Library
    handles {|name| File.exists?(library_file(name.to_s)) }

    def load_init
      super
      @loader[:no_module_eval] ||= @loader.has_key?(:module)
    end

    def read_library
      if @loader[:no_module_eval]
        Kernel.load self.class.library_file(@name)
      else
        library_string = File.read(self.class.library_file(@name))
        Libraries.module_eval(library_string, self.class.library_file(@name))
      end
    end

    def load_source
      detected = detect_additions(:modules=>true) { read_library }
      @loader[:module] = determine_lib_module(detected[:modules]) unless @loader[:module]
    end

    def reload_source; read_library; end

    def determine_lib_module(detected_modules)
      case detected_modules.size
      when 1 then lib_module = detected_modules[0]
      when 0 then raise LoaderError, "Can't detect module. Make sure at least one module is defined in the library."
      else
        unless ((lib_module = Util.constantize("boson/libraries/#{@loader[:name]}")) && lib_module.to_s[/^Boson::Libraries/])
          raise LoaderError, "Can't detect module. Specify a module in this library's config."
        end
      end
      lib_module
    end
  end

  class GemLibrary < Library
    def self.is_a_gem?(name)
      Gem.searcher.find(name).is_a?(Gem::Specification)
    end

    handles {|name| is_a_gem?(name.to_s) }

    def initialize_library_module
      super if @loader[:module]
    end

    def is_valid_library?
      !@loader[:gems].empty? || !@loader[:commands].empty? || @loader.has_key?(:module)
    end

    def load_source
      detect_additions { Util.safe_require @name }
    end
  end
end
