module Boson
  # This library is based on a file of the same name under the commands directory of a repository.
  # Since there can be multiple repositories, a library's file is looked for in the order given by
  # Boson.repos.
  #
  # To create this library, simply create a file with a module and some methods (See Library
  # for naming a module). Non-private methods are automatically loaded as a library's commands.
  #
  # Take for example a library brain.rb:
  #   module Brain
  #     def take_over(destination)
  #       puts "Pinky, it's time to take over the #{destination}!"
  #     end
  #   end
  #
  # Once loaded, this library can be run from the commandline or irb:
  #  bash> boson take_over world
  #  irb>> take_over 'world'
  #
  # If the library is namespaced, the command would be run as brain.take_over.
  #
  # Let's give Brain an option in his conquest:
  #   module Brain
  #     options :execute=>:string
  #     def take_over(destination, options={})
  #       puts "Pinky, it's time to take over the #{destination}!"
  #       system(options[:execute]) if options[:execute]
  #     end
  #   end
  #
  # From the commandline and irb this runs as:
  #   bash> boson take_over world -e initiate_brainiac
  #   irb>> take_over 'world -e initiate_brainiac'
  #
  # To learn more about the depth of option types available to a command, see OptionParser.
  #
  # Since boson aims to make your libraries just standard ruby, we can achieve the above
  # by placing options in comments above a method:
  #   module Brain
  #     # @options :execute=>:string
  #     # Help Brain live the dream
  #     def take_over(destination, options={})
  #       puts "Pinky, it's time to take over the #{destination}!"
  #       system(options[:execute]) if options[:execute]
  #     end
  #   end
  #
  # Some points about the above:
  # * A '@' must prefix options and other method calls that become comments.
  # * Note the comment above the method. One-line comments right before a method set a command's description.
  # * See MethodInspector for other command attributes, like options, that can be placed above a method.
  # * See CommentInspector for the rules about commenting command attributes.
  #
  # Once a command has a defined option, a command can also recognize a slew of global options:
  #   irb>> take_over '-h'
  #   take_over [destination] [--execute=STRING]
  #
  #   # prints much more verbose help
  #   irb>> take_over '-hv'
  #
  # For more about these global options see Scientist.
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
        command_modules = detected_modules.map {|e| e.to_s}.grep(/^Boson::Commands/)
        unless command_modules.size == 1 && (lib_module = command_modules[0])
          raise LoaderError, "Can't detect module. Specify a module in this library's config."
        end
      end
      lib_module
    end
    #:startdoc:
  end
end