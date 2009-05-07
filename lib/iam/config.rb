module Iam
  module Config
    def config(reload=false)
      if reload || @config.nil?
        @config = YAML::load_file(Iam.base_dir + '/iam.yml') rescue {:commands=>{}, :libraries=>{}}
      end
      @config
    end
  end
end