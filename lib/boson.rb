require 'yaml'
require 'hirb'
require 'alias'
$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'boson/manager'
require 'boson/library'
require 'boson/util'
require 'boson/libraries/core'
require 'boson/libraries/object_commands'
require 'boson/searchable_array'
require 'boson/loader'

module Boson
  class <<self
    attr_accessor :dir, :main_object
    alias_method :higgs, :main_object

    def libraries
      @libraries ||= SearchableArray.new
    end

    def commands
      @commands ||= SearchableArray.new
    end

    def dir
      @dir ||= File.expand_path(File.exists?('.irb') ? '.irb' : "#{ENV['HOME']}/.irb")
    end

    def config(reload=false)
      if reload || @config.nil?
        @config = YAML::load_file(Boson.dir + '/boson.yml') rescue {:commands=>{}, :libraries=>{}}
      end
      @config
    end

    def activate(options={})
      Manager.activate(options)
    end
  end  
end

Boson.main_object = self