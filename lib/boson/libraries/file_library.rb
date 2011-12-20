module Boson
  # This class loads a file by its path relative to the commands directory of a repository.
  # For example the library 'public/misc' could refer to the file '~/.boson/commands/public/misc.rb'.
  # If a file's basename is unique in its repository, then it can be loaded with its basename i.e. 'misc'
  # for the previous example. When loading a library, this class searches repositories in the order given by
  # Boson.repos.
  #
  # === Creating a FileLibrary
  # Start by creating a file with a module and some methods (See Library for naming a module).
  # Non-private methods are automatically loaded as a library's commands.
  #
  # Take for example a library brain.rb:
  #   # Drop this in ~/.boson/commands/brain.rb
  #   module Brain
  #     def take_over(destination)
  #       puts "Pinky, it's time to take over the #{destination}!"
  #     end
  #   end
  #
  # Once loaded, this library can be run from the commandline or irb:
  #  $ boson take_over world
  #  >> take_over 'world'
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
  #   $ boson take_over world -e initiate_brainiac
  #   >> take_over 'world -e initiate_brainiac'
  #
  # Since Boson aims to make your libraries just standard ruby, we can achieve the above
  # by making options a commented method attribute:
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
  # * A '@' must prefix options and other method attributes that become comments.
  # * Note the comment above the method. One-line comments right before a method set a command's description.
  # * See Inspector for other method attributes, like config that can be placed above a method.
  #
  # Once a command has a defined option, a command can also recognize a slew of global options:
  #   >> take_over '-h'
  #   take_over [destination] [--execute=STRING]
  #
  #   # prints much more verbose help
  #   >> take_over '-hv'
  #
  # For more about these global options see OptionCommand and View.
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
        @file_cache.delete(library_file(name, (matched_repo || Boson.repo).dir))
      else
        @file_cache = nil
      end
    end

    handles {|source|
      @repo = Boson.repos.find {|e| File.exists? library_file(source.to_s, e.dir) } ||
       Boson.repos.find {|e|
        Dir["#{e.commands_dir}/**/*.rb"].grep(/\/#{source}\.rb/).size == 1
        }
      !!@repo
    }

    def library_file(name=@name)
      self.class.library_file(name, @repo_dir)
    end

    def set_repo
      self.class.matched_repo
    end

    def set_name(name)
      @lib_file = File.exists?(library_file(name.to_s)) ? library_file(name.to_s) :
        Dir[self.class.matched_repo.commands_dir.to_s+'/**/*.rb'].find {|e| e =~ /\/#{name}\.rb$/}
      @lib_file.gsub(/^#{self.class.matched_repo.commands_dir}\/|\.rb$/, '')
    end

    def base_module
      @base_module ||= @name.include?('/') ? create_module_from_path : Commands
    end

    def load_source(reload=false)
      library_string = self.class.read_library_file(@lib_file, reload)
      Inspector.enable
      base_module.module_eval(library_string, @lib_file)
      Inspector.disable
    end

    def create_module_from_path(index=-2)
      @name.split('/')[0..index].inject(Boson::Commands) {|base, e|
        base.const_defined?(sub_mod = Util.camelize(e)) ? base.const_get(sub_mod) :
          Util.create_module(base, e)
      }
    end

    def load_source_and_set_module
      detected = detect_additions(:modules=>true) { load_source }
      @module = determine_lib_module(detected[:modules]) unless @module
    end

    def determine_lib_module(detected_modules)
      detected_modules = detected_modules.select {|e| e.to_s[/^#{base_module}::/] }
      case detected_modules.size
      when 1 then lib_module = detected_modules[0]
      when 0 then lib_module = create_module_from_path(-1)
      else
        unless (lib_module = Util.constantize("boson/commands/#{@name}")) && lib_module.to_s[/^Boson::Commands/]
          raise LoaderError, "Can't detect module. Specify a module in this library's config."
        end
      end
      lib_module
    end
    #:startdoc:
  end
end
