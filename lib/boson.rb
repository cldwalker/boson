require 'yaml'
require 'hirb'
require 'alias'
$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'boson/config'
require 'boson/manager'
require 'boson/library'
require 'boson/util'
require 'boson/commands'
require 'boson/searchable_array'

module Boson
  extend Config
  module Libraries; end
  module ObjectCommands; end
  class <<self
    attr_reader :base_dir, :libraries, :base_object, :commands
    
    def init_called?; @init_called || false; end

    def init(options={})
      @libraries ||= SearchableArray.new
      @commands ||= SearchableArray.new
      @base_dir = File.expand_path options[:base_dir] || (File.exists?("#{ENV['HOME']}/.irb") ? "#{ENV['HOME']}/.irb" : '.irb')
      $:.unshift @base_dir unless $:.include? File.expand_path(@base_dir)
      @base_object = options[:with] || @base_object || Object.new
      @base_object.extend Libraries
      Alias.init
      create_default_libraries(options)
      Manager.create_config_libraries
      load_default_libraries(options)
      @init_called = true
    end

    def load_default_libraries(options)
      defaults = [Boson::Commands, Boson::ObjectCommands]
      defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
      defaults += config[:defaults] if config[:defaults]
      Manager.load_libraries(defaults)
    end

    def create_default_libraries(options)
      detected_libraries = Dir[File.join(Boson.base_dir, 'libraries', '**/*.rb')].map {|e| e.gsub(/.*libraries\//,'').gsub('.rb','') }
      Manager.create_libraries(detected_libraries, options)
    end

    # can only be run once b/c of alias and extend
    def register(*args)
      options = args[-1].is_a?(Hash) ? args.pop : {}
      init(options) unless init_called?
      Manager.load_libraries(args)
    end
  end  
end
