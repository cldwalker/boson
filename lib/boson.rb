$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
%w{hirb alias}.each {|e| require e }
%w{runner runners/repl_runner repo loader inspector library}.each {|e| require "boson/#{e}" }
%w{argument method comment}.each {|e| require "boson/inspectors/#{e}_inspector" }
# order of library subclasses matters
%w{module file gem require}.each {|e| require "boson/libraries/#{e}_library" }
%w{view command util commands option_parser index higgs}.each {|e| require "boson/#{e}" }

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

  def repo
    @repo ||= Repo.new("#{ENV['HOME']}/.boson")
  end

  def local_repo
    @local_repo ||= begin
      dir = ["lib/boson", ".boson"].find {|e| File.directory?(e) &&
         File.expand_path(e) != repo.dir }
      Repo.new(dir) if dir
    end
  end

  def repos
    @repos ||= [repo, local_repo].compact
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