require File.join(File.dirname(__FILE__), 'test_helper')

describe "file library" do
  before { reset; FileLibrary.reset_file_cache }
  before { Gem.stubs(:loaded_specs).returns({}) } if RUBY_VERSION >= '1.9.2'

  it "loads" do
    load :blah, :file_string=>"module Blah; def blah; end; end"
    library_has_module('blah', 'Boson::Commands::Blah')
    command_exists?('blah')
  end

  it "in a subdirectory loads" do
    load 'site/delicious', :file_string=>"module Delicious; def blah; end; end"
    library_has_module('site/delicious', "Boson::Commands::Site::Delicious")
    command_exists?('blah')
  end

  it "in a sub subdirectory loads" do
    load 'web/site/delicious', :file_string=>"module Delicious; def blah; end; end"
    library_has_module('web/site/delicious', "Boson::Commands::Web::Site::Delicious")
    command_exists?('blah')
  end

  it "loads by basename" do
    Dir.stubs(:[]).returns([RUBY_VERSION < '1.9.2' ? './test/commands/site/github.rb' :
      File.expand_path('./test/commands/site/github.rb')])
    load 'github', :file_string=>"module Github; def blah; end; end", :exists=>false
    library_has_module('site/github', "Boson::Commands::Site::Github")
    command_exists?('blah')
  end

  it "loads a plugin library by creating its module" do
    load(:blah, :file_string=>"def blah; end")
    library_has_module('blah', "Boson::Commands::Blah")
    command_exists?('blah', false)
  end

  it "prints error for file library with multiple modules" do
    capture_stderr { load(:blah, :file_string=>"module Doo; end; module Daa; end") }.should =~ /Can't.*config/
  end
end