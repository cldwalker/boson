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
      @config_dir ||= FileUtils.mkdir_p("#{dir}/config") && "#{dir}/config"
    end

    # Points to the commands/ subdirectory and is automatically created when called. Used for command libraries.
    def commands_dir
      @commands_dir ||= (cdir = self.class.commands_dir(@dir)) && FileUtils.mkdir_p(cdir) && cdir
    end

    # A hash read from the YAML config file at config/boson.yml.
    # ==== Valid config keys:
    # [:libraries] Hash of libraries mapping their name to attribute hashes. See Library.new for configurable attributes.
    #               Example:
    #               :libraries=>{'completion'=>{:namespace=>true}}
    # [:command_aliases] Hash of commands names and their aliases. Since this is global it will be read by _all_ libraries.
    #                    This is useful for quickly creating aliases without having to worry about placing them under
    #                    the correct library config. For non-global aliasing, aliases should be placed under the :command_aliases
    #                    key of a library entry in :libraries.
    #                     Example:
    #                      :command_aliases=>{'libraries'=>'lib', 'commands'=>'com'}
    # [:defaults] Array of libraries to load at start up when used in irb.
    # [:bin_defaults] Array of libraries to load at start up when used from the commandline.
    # [:add_load_path] Boolean specifying whether to add a load path pointing to the lib subdirectory/. This is useful in sharing
    #                  classes between libraries without resorting to packaging them as gems. Defaults to false if the lib
    #                  subdirectory doesn't exist in the boson directory.
    # [:error_method_conflicts] Boolean specifying library loading behavior when its methods conflicts with existing methods in
    #                           the global namespace. When set to false, Boson automatically puts the library in its own namespace.
    #                           When set to true, the library fails to load explicitly. Default is false.
    # [:auto_namespace] Boolean which automatically namespaces all user-defined libraries. Default is false.
    def config(reload=false)
      if reload || @config.nil?
        default = {:libraries=>{}, :command_aliases=>{}, :defaults=>[]}
        @config = default.merge(YAML::load_file(config_dir + '/boson.yml')) rescue default
      end
      @config
    end
  end
end