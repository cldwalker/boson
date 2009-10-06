%w{yaml fileutils}.each {|e| require e }
module Boson
  class Repo
    def self.commands_dir(dir)
      File.join(dir, 'commands')
    end

    attr_accessor :dir, :config
    def initialize(dir)
      @dir = dir
    end

    def config_dir
      @config_dir ||= FileUtils.mkdir_p File.join(dir, 'config')
    end

    def commands_dir
      @commands_dir ||= FileUtils.mkdir_p self.class.commands_dir(@dir)
    end

    # ==== Valid config keys:
    # [:libraries] Hash of libraries mapping their name to attribute hashes.
    # [:commands] Hash of commands mapping their name to attribute hashes.
    # [:defaults] Array of libraries to load at start up.
    # [:add_load_path] Boolean specifying whether to add a load path pointing to the lib under boson's directory. Defaults to false if
    #                  the lib directory isn't defined in the boson directory. Default is false.
    # [:error_method_conflicts] Boolean specifying library loading behavior when one of its methods conflicts with existing methods in
    #                           the global namespace. When set to false, Boson automatically puts the library in its own namespace.
    #                           When set to true, the library fails to load explicitly. Default is false.
    def config(reload=false)
      if reload || @config.nil?
        default = {:commands=>{}, :libraries=>{}, :command_aliases=>{}, :defaults=>[]}
        @config = default.merge(YAML::load_file(config_dir + '/boson.yml')) rescue default
      end
      @config
    end
  end
end