require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
begin
  require 'rcov/rcovtask'

  Rcov::RcovTask.new do |t|
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb']
    t.rcov_opts = ["-T -x '/Library/Ruby/*'"]
    t.verbose = true
  end
rescue LoadError
  puts "Rcov not available. Install it for rcov-related tasks with: sudo gem install rcov"
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "boson"
    s.description = "A command/task framework similar to rake and thor that opens your ruby universe to the commandline and irb."
    s.summary =  "Boson provides users with the power to turn any ruby method into a full-fledged commandline tool. Boson achieves this with powerful options (borrowed from thor) and views (thanks to hirb). Some other unique features that differentiate it from rake and thor include being accessible from irb and the commandline, being able to write boson commands in non-dsl ruby and toggling a pretty view of a command's output without additional view code."
    s.email = "gabriel.horner@gmail.com"
    s.homepage = "http://tagaholic.me/boson/"
    s.authors = ["Gabriel Horner"]
    s.has_rdoc = true
    s.rubyforge_project = 'tagaholic'
    s.add_dependency 'hirb', '>= 0.2.10'
    s.add_dependency 'alias', '>= 0.2.1'
    s.extra_rdoc_files = ["README.rdoc", "LICENSE.txt"]
    s.files = FileList["Rakefile", "VERSION.yml", "README.rdoc", "LICENSE.txt", "{bin,lib,test}/**/*"]
  end

rescue LoadError
  puts "Jeweler not available. Install it for jeweler-related tasks with: sudo gem install jeweler"
end

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'test'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :default => :test
