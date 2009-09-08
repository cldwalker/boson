require 'yaml'
require 'hirb'
require 'alias'
require 'fileutils'

$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'boson/runner'
require 'boson/runners/repl_runner'
require 'boson/repo'
require 'boson/loader'
require 'boson/library'
# order of library subclasses matters
require 'boson/libraries/module_library'
require 'boson/libraries/file_library'
require 'boson/libraries/gem_library'
require 'boson/libraries/require_library'
require 'boson/command'
require 'boson/util'
require 'boson/commands/core'
require 'boson/commands/web_core'
require 'boson/commands/irb_core'
require 'boson/commands/namespace'

module Boson
  module Universe; end
  extend self
  attr_accessor :main_object, :commands, :libraries
  alias_method :higgs, :main_object

  def libraries
    @libraries ||= Array.new
  end

  def library(query, attribute='name')
    libraries.find {|e| e.send(attribute) == query }
  end

  def commands
    @commands ||= Array.new
  end

  def command(query, attribute='name')
    commands.find {|e| e.send(attribute) == query }
  end

  def dir
    repo.dir
  end

  def repo
    @repo ||= Repo.new("#{ENV['HOME']}/.boson")
  end

  def repos
    @repos ||= [repo] + ["lib/boson", ".boson"].select {|e|
      File.directory?(e)}.map {|e| Repo.new(File.expand_path(e))}
  end

  def main_object=(value)
    @main_object = value.extend(Universe)
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
    repo.config(reload)
  end

  def config_dir
    repo.config_dir
  end

  def commands_dir
    repo.commands_dir
  end

  def activate(options={})
    ReplRunner.start(options)
  end

  def invoke(*args, &block)
    main_object.send(*args, &block)
  end
end

Boson.main_object = self