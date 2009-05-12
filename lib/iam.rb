require 'yaml'
require 'hirb'
require 'alias'
$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'iam/config'
require 'iam/manager'
require 'iam/library'
require 'iam/util'
require 'iam/commands'
require 'iam/searchable_array'

module Iam
  extend Config
  module Libraries; end
  class <<self
    attr_reader :base_dir, :libraries, :base_object, :commands
    def init(options={})
      @libraries ||= SearchableArray.new
      @commands ||= SearchableArray.new
      @base_dir = options[:base_dir] || (File.exists?("#{ENV['HOME']}/.irb") ? "#{ENV['HOME']}/.irb" : '.irb')
      $:.unshift @base_dir unless $:.include? File.expand_path(@base_dir)
      load File.join(@base_dir, 'libraries.rb') if File.exists?(File.join(@base_dir, 'libraries.rb'))
      @base_object = options[:with] || @base_object || Object.new
      @base_object.send :extend, Iam::Libraries
      create_default_libraries(options)
    end

    def create_default_libraries(options)
      defaults = [Iam::Commands]
      defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
      Manager.create_libraries(defaults, options)
    end

    # can only be run once b/c of alias and extend
    def register(*args)
      options = args[-1].is_a?(Hash) ? args.pop : {}
      init(options)
      Manager.create_libraries(args, options)
      Manager.create_config_libraries
      Manager.create_aliases
    end
  end  
end