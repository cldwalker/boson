require 'boson/bare_runner'
require 'boson/manager'
require 'boson/loader'
require 'boson/inspector'
require 'boson/library'
require 'boson/method_inspector'
require 'boson/runner_library'
require 'boson/command'
require 'boson/util'
require 'boson/option_parser'
require 'boson/options'
require 'boson/scientist'
require 'boson/option_command'
require 'boson/version'

# This module stores the libraries, commands and the main_object.
#
# Useful documentation links:
# * Boson::Library - All about libraries
# * Boson::Loader - Explains library module callbacks
# * Boson::OptionParser - All about options
module Boson
  extend self

  # Module which is extended by Boson.main_object to give it command functionality.
  module Universe;  end
  # Module under which most library modules are evaluated.
  module Commands; end

  # Default config
  CONFIG = {libraries: {}, command_aliases: {}, option_underscore_search: true}

  # The object which holds and executes all command functionality
  attr_accessor :main_object
  alias_method :higgs, :main_object

  attr_accessor :commands, :libraries, :config
  # Prints debugging info when set
  attr_accessor :debug
  # Returns true if commands are being executed from a non-ruby shell i.e. bash
  # Returns nil/false if in a ruby shell i.e. irb.
  attr_accessor :in_shell
  # Returns true if in commandline with verbose flag or if set explicitly.
  # Plugins should use this to display more info.
  attr_accessor :verbose

  # Array of loaded Boson::Library objects.
  def libraries
    @libraries ||= Array.new
  end

  # Array of loaded Boson::Command objects.
  def commands
    @commands ||= Array.new
  end

  # Global config used by most classes
  def config
    @config ||= CONFIG
  end

  # Sets main_object and extends it with commands from Universe
  def main_object=(value)
    @main_object = value.extend(Universe)
  end

  # Finds first library that has a value of attribute
  def library(query, attribute='name')
    libraries.find {|e| e.send(attribute) == query }
  end

  # Invoke an action on the main object.
  def invoke(*args, &block)
    main_object.send(*args, &block)
  end

  # Similar to invoke but accepts args as an array
  def full_invoke(cmd, args)
    main_object.send(cmd, *args)
  end

  # Boolean indicating if the main object can invoke the given method/command.
  def can_invoke?(meth, priv=true)
    Boson.main_object.respond_to? meth, priv
  end
end

Boson.main_object = self
