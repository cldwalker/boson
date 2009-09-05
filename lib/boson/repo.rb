module Boson
  class Repo
    attr_accessor :dir, :config
    def initialize(dir)
      @dir = dir
    end

    def config_dir
      @config_dir ||= FileUtils.mkdir_p File.join(dir, 'config')
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