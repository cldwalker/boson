module Boson
  module Config
    def config(reload=false)
      if reload || @config.nil?
        @config = YAML::load_file(Boson.base_dir + '/boson.yml') rescue {:commands=>{}, :libraries=>{}}
      end
      @config
    end
  end
end
