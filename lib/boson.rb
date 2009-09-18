$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'yaml'
require 'hirb'
require 'alias'
require 'fileutils'
require 'boson/runner'
require 'boson/runners/repl_runner'
require 'boson/repo'
require 'boson/loader'
require 'boson/inspector'
require 'boson/argument_inspector'
require 'boson/scraper'
require 'boson/library'
# order of library subclasses matters
require 'boson/libraries/module_library'
require 'boson/libraries/file_library'
require 'boson/libraries/gem_library'
require 'boson/libraries/require_library'
require 'boson/command'
require 'boson/util'
require 'boson/commands'
require 'boson/option_parser'

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

  def start(options={})
    ReplRunner.start(options)
  end

  def invoke(*args, &block)
    main_object.send(*args, &block)
  end
end

Boson.main_object = self