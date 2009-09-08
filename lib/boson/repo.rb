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
      self.class.commands_dir(@dir)
    end

    def config(reload=false)
      if reload || @config.nil?
        default = {:commands=>{}, :libraries=>{}, :command_aliases=>{}, :defaults=>[]}
        @config = default.merge(YAML::load_file(config_dir + '/boson.yml')) rescue default
      end
      @config
    end
  end
end