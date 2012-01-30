%w{bare_runner manager loader inspector library}.each {|e| require "boson/#{e}" }
require 'boson/method_inspector'
require 'boson/runner_library'
%w{command util option_parser options scientist option_command version}.
  each {|e| require "boson/#{e}" }

# This module stores the libraries, commands and main object used throughout Boson.
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

  # Array of loaded Boson::Library objects.
  def libraries
    @libraries ||= Array.new
  end

  # Array of loaded Boson::Command objects.
  def commands
    @commands ||= Array.new
  end

  def config
    @config ||= CONFIG
  end

  def main_object=(value) #:nodoc:
    @main_object = value.extend(Universe)
  end

  def library(query, attribute='name') #:nodoc:
    libraries.find {|e| e.send(attribute) == query }
  end

  # Invoke an action on the main object.
  def invoke(*args, &block)
    main_object.send(*args, &block)
  end

  def full_invoke(cmd, args)
    main_object.send(cmd, *args)
  end

  # Boolean indicating if the main object can invoke the given method/command.
  def can_invoke?(meth, priv=true)
    Boson.main_object.respond_to? meth, priv
  end
end

Boson.main_object = self
