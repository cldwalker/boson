require 'yaml'
require 'hirb'
require 'alias'
$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'boson/runner'
require 'boson/loader'
require 'boson/library'
# order of library subclasses matters
require 'boson/libraries/module_library'
require 'boson/libraries/file_library'
require 'boson/libraries/gem_library'
require 'boson/command'
require 'boson/util'
require 'boson/commands/core'
require 'boson/commands/namespace'
require 'boson/searchable_array'

module Boson
  class <<self
    attr_accessor :dir, :main_object, :config
    alias_method :higgs, :main_object

    def libraries
      @libraries ||= SearchableArray.new
    end

    def commands
      @commands ||= SearchableArray.new
    end

    def dir
      @dir ||= File.expand_path(File.exists?('.boson') ? '.boson' : "#{ENV['HOME']}/.boson")
    end

    def main_object=(value)
      @main_object = value.extend(Commands)
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

    def config_dir
      File.join(dir, 'config')
    end

    def commands_dir
      File.join(dir, 'commands')
    end

    def activate(options={})
      Runner.activate(options)
    end

    def invoke(*args)
      main_object.send(*args)
    end
  end
end

Boson.main_object = self