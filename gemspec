# -*- encoding: utf-8 -*-
require 'rubygems' unless Object.const_defined?(:Gem)
require File.dirname(__FILE__) + "/lib/boson/version"
 
Gem::Specification.new do |s|
  s.name        = "boson"
  s.version     = Boson::VERSION
  s.authors     = ["Gabriel Horner"]
  s.email       = "gabriel.horner@gmail.com"
  s.homepage    = "http://tagaholic.me/boson/"
  s.summary = "A command/task framework similar to rake and thor that opens your ruby universe to the commandline and irb."
  s.description =  "Boson provides users with the power to turn any ruby method into a full-fledged commandline tool. Boson achieves this with powerful options (borrowed from thor) and views (thanks to hirb). Some other unique features that differentiate it from rake and thor include being accessible from irb and the commandline, being able to write boson commands in non-dsl ruby and toggling a pretty view of a command's output without additional view code."
  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project = 'tagaholic'
  s.add_dependency 'hirb', '>= 0.2.10'
  s.add_dependency 'alias', '>= 0.2.1'
  s.files = Dir.glob(%w[{lib,test}/**/*.rb bin/* [A-Z]*.{txt,rdoc} ext/**/*.{rb,c}]) + %w{Rakefile gemspec}
  s.extra_rdoc_files = ["README.rdoc", "LICENSE.txt"]
end