%w{alias boson/commands}.each {|e| require e }
%w{runner manager loader inspector library}.each {|e| require "boson/#{e}" }
require 'boson/method_inspector'
require 'boson/runner_library'
%w{namespace command util option_parser options scientist option_command version}.
  each {|e| require "boson/#{e}" }

# This module stores the libraries, commands and main object used throughout Boson.
#
# Useful documentation links:
# * Boson::Library - All about libraries
# * Boson::FileLibrary - Explains creating libraries as files
# * Boson::Loader - Explains library module callbacks
# * Boson::OptionParser - All about options
module Boson
  # Module which is extended by Boson.main_object to give it command functionality.
  module Universe; include Commands::Namespace; end
  CONFIG = {libraries: {}, command_aliases: {}, option_underscore_search: true}
  NAMESPACE = '.' # Delimits namespace from command
  extend self
  # The object which holds and executes all command functionality
  attr_accessor :main_object
  attr_accessor :commands, :libraries, :config
  alias_method :higgs, :main_object

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

  # Invoke command string even with namespaces
  def full_invoke(cmd, args) #:nodoc:
    command, subcommand = cmd.include?(NAMESPACE) ? cmd.split(NAMESPACE, 2) : [cmd, nil]
    dispatcher = subcommand ? Boson.invoke(command) : Boson.main_object
    dispatcher.send(subcommand || command, *args)
  end

  # Boolean indicating if the main object can invoke the given method/command.
  def can_invoke?(meth, priv=true)
    Boson.main_object.respond_to? meth, priv
  end
end

Boson.main_object = self
