%w{hirb alias boson/commands}.each {|e| require e }
%w{runner repo manager loader inspector library}.each {|e| require "boson/#{e}" }
%w{argument method comment}.each {|e| require "boson/inspectors/#{e}_inspector" }
# order of library subclasses matters
%w{module file gem require local_file}.each {|e| require "boson/libraries/#{e}_library" }
(%w{namespace view command util option_parser options} +
  %w{index repo_index version}).each {|e| require "boson/#{e}" }

# This module stores the libraries, commands, repos and main object used throughout Boson.
#
# Useful documentation links:
# * Boson::BinRunner - Runs the boson executable
# * Boson::Repo.config - Explains main config file
# * Boson::Library - All about libraries
# * Boson::FileLibrary - Explains creating libraries as files
# * Boson::Loader - Explains library module callbacks
# * Boson::OptionParser - All about options
module Boson
  # Module which is extended by Boson.main_object to give it command functionality.
  module Universe; include Commands::Namespace; end
  NAMESPACE = '.' # Delimits namespace from command
  extend self
  # The object which holds and executes all command functionality
  attr_accessor :main_object
  attr_accessor :commands, :libraries
  alias_method :higgs, :main_object

  # Array of loaded Boson::Library objects.
  def libraries
    @libraries ||= Array.new
  end

  # Array of loaded Boson::Command objects.
  def commands
    @commands ||= Array.new
  end

  # The main required repository which defaults to ~/.boson.
  def repo
    @repo ||= Repo.new("#{ENV['BOSON_HOME'] || Dir.home}/.boson")
  end

  # An optional local repository which defaults to ./lib/boson or ./.boson.
  def local_repo
    @local_repo ||= begin
      ignored_dirs = (repo.config[:ignore_directories] || []).map {|e| File.expand_path(e) }
      dir = ["lib/boson", ".boson"].find {|e| File.directory?(e) &&
          File.expand_path(e) != repo.dir && !ignored_dirs.include?(File.expand_path('.')) }
      Repo.new(dir) if dir
    end
  end

  # The array of loaded repositories containing the main repo and possible local and global repos
  def repos
    @repos ||= [repo, local_repo, global_repo].compact
  end

  # Optional global repository at /etc/boson
  def global_repo
    File.exists?('/etc/boson') ? Repo.new('/etc/boson') : nil
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
