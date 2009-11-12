%w{yaml fileutils}.each {|e| require e }
module Boson
  # A class for repositories. A repository has a root directory with required subdirectories config/ and
  # commands/ and optional subdirectory lib/. Each repository has a primary config file at config/boson.yml.
  class Repo
    def self.commands_dir(dir) #:nodoc:
      File.join(dir, 'commands')
    end

    attr_accessor :dir, :config
    # Creates a repository given a root directory.
    def initialize(dir)
      @dir = dir
    end

    # Points to the config/ subdirectory and is automatically created when called. Used for config files.
    def config_dir
      @config_dir ||= FileUtils.mkdir_p(config_dir_path) && config_dir_path
    end

    def config_dir_path
      "#{dir}/config"
    end

    # Path name of main config file. If passed true, parent directory of file is created.
    def config_file(create_dir=false)
      File.join((create_dir ? config_dir : config_dir_path), 'boson.yml')
    end

    # Points to the commands/ subdirectory and is automatically created when called. Used for command libraries.
    def commands_dir
      @commands_dir ||= (cdir = self.class.commands_dir(@dir)) && FileUtils.mkdir_p(cdir) && cdir
    end

    # A hash read from the YAML config file at config/boson.yml.
    # {See here}[http://github.com/cldwalker/irbfiles/blob/master/boson/config/boson.yml] for an example config file.
    # Top level config keys, library attributes and config attributes need to be symbols.
    # ==== Config keys for all repositories:
    # [:libraries] Hash of libraries mapping their name to attribute hashes. See Library.new for configurable attributes.
    #               Example:
    #               :libraries=>{'completion'=>{:namespace=>true}}
    # [:command_aliases] Hash of commands names and their aliases. Since this is global it will be read by _all_ libraries.
    #                    This is useful for quickly creating aliases without having to worry about placing them under
    #                    the correct library config. For non-global aliasing, aliases should be placed under the :command_aliases
    #                    key of a library entry in :libraries.
    #                     Example:
    #                      :command_aliases=>{'libraries'=>'lib', 'commands'=>'com'}
    # [:defaults] Array of libraries to load at start up for commandline and irb. This is useful for extending boson i.e. adding your
    #             own option types. Default is no libraries.
    # [:console_defaults] Array of libraries to load at start up when used in irb. Default is to load all library files and libraries
    #                     defined in the config.
    # [:bin_defaults] Array of libraries to load at start up when used from the commandline. Default is no libraries.
    # [:add_load_path] Boolean specifying whether to add a load path pointing to the lib subdirectory/. This is useful in sharing
    #                  classes between libraries without resorting to packaging them as gems. Defaults to false if the lib
    #                  subdirectory doesn't exist in the boson directory.
    #
    # ==== Config keys specific only for the main repo config ~/.boson/config/boson.yml
    # [:global_options] Custom global options available to all option commands. These are merged with Boson::Scientist::GLOBAL_OPTIONS.
    # [:render_options] Custom render options available to all option commands. These are merged with Boson::Scientist::RENDER_OPTIONS.
    # [:error_method_conflicts] Boolean specifying library loading behavior when its methods conflicts with existing methods in
    #                           the global namespace. When set to false, Boson automatically puts the library in its own namespace.
    #                           When set to true, the library fails to load explicitly. Default is false.
    # [:console] Console to load when using --console from commandline. Default is irb.
    # [:auto_namespace] Boolean which automatically namespaces all user-defined libraries. Be aware this can break libraries which
    #                   depend on commands from other libraries. Default is false.
    def config(reload=false)
      if reload || @config.nil?
        begin
          @config = {:libraries=>{}, :command_aliases=>{}, :console_defaults=>[]}
          @config.merge!(YAML::load_file(config_file(true))) if File.exists?(config_file)
        rescue ArgumentError
          message = $!.message !~ /syntax error on line (\d+)/ ? "Error"+$!.message :
            "Error: Syntax error in line #{$1} of config file '#{config_file}'"
          Kernel.abort message
        end
      end
      @config
    end

    def detected_libraries #:nodoc:
      Dir[File.join(commands_dir, '**/*.rb')].map {|e| e.gsub(/^#{commands_dir}\/|\.rb$/, '') }
    end

    def all_libraries #:nodoc:
      (detected_libraries + config[:libraries].keys).uniq
    end
  end
end