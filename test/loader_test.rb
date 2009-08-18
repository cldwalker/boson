require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LoaderTest < Test::Unit::TestCase
    def setup_load(lib, options={})
      unless lib.is_a?(Module) || options[:no_mock]
        options[:file_string] ||= ''
        if options.delete(:gem)
          File.expects(:exists?).returns(false)
          Loader.expects(:is_a_gem?).returns(true)
          Util.expects(:safe_require).with { eval options.delete(:file_string); true}.returns(true)
        else
          File.expects(:exists?).with(Loader.library_file(lib.to_s)).returns(true)
          if options.delete(:no_module_eval)
            Kernel.expects(:load).with { eval options.delete(:file_string); true}.returns(true)
          else
            File.expects(:read).returns(options.delete(:file_string))
          end
        end
      end
      Loader.stubs(:is_a_gem?).returns(true) if options.delete(:no_mock)
    end

    def load(lib, options={})
      setup_load(lib, options)
      Library.load([lib], options)
    end

    def library(name)
      Boson.libraries.find_by(:name=>name)
    end

    def library_has_module(lib, lib_module)
      Library.loaded?(lib).should == true
      test_lib = library(lib)
      (test_lib[:module].is_a?(Module) && (test_lib[:module].to_s == lib_module)).should == true
    end

    before(:each) { reset_main_object; reset_libraries; reset_commands }

    context "load_library" do
      test "loads a module library" do
        eval %[module ::Harvey; def bird; end; end]
        load ::Harvey
        library_has_module('harvey', "Harvey")
        command_exists?('bird').should == true
      end

      test "calls included hook of a file library" do
        capture_stdout {
          load :blah, :file_string=>"module Blah; def self.included(mod); puts 'included blah'; end; def blah; end; end"
        }.should =~ /included blah/
      end

      test "loads a file library" do
        load :blah, :file_string=>"module Blah; def blah; end; end"
        library_has_module('blah', 'Boson::Libraries::Blah')
        command_exists?('blah').should == true
      end

      test "loads a file library with config module" do
        with_config(:libraries=>{"blah"=>{:module=>"Coolness"}}) do
          load :blah, :file_string=>"module ::Coolness; def coolness; end; end", :no_module_eval=>true
        end
        library_has_module('blah', 'Coolness')
        command_exists?('coolness').should == true
      end

      test "loads a file library with config no_module_eval" do
        with_config(:libraries=>{"blah"=>{:no_module_eval=>true}}) do
          load :blah, :file_string=>"module ::Bogus; end; module Boson::Libraries::Blah; def blah; end; end", :no_module_eval=>true
        end
        library_has_module('blah', 'Boson::Libraries::Blah')
        command_exists?('blah').should == true
      end

      test "loads a file library with config call_methods" do
        with_config(:libraries=>{"blah"=>{:call_methods=>['blah']}}) do
          capture_stdout {
            load :blah, :file_string=>"module Blah; def blah; puts 'yo'; end; end"
          }.should == "yo\n"
        end
      end

      test "prints error for file library with no module" do
        capture_stderr { load(:blah, :file_string=>"def blah; end") }.should =~ /Can't.*at least/
      end

      test "prints error for file library with multiple modules" do
        capture_stderr { load(:blah, :file_string=>"module Doo; end; module Daa; end") }.should =~ /Can't.*config/
      end

      test "prints error for generally invalid library" do
        capture_stderr { load('blah', :gem=>true) }.should =~ /Unable.*load/
      end

      test "returns false for existing library" do
        Boson.libraries << Library.new(:name=>'blah', :loaded=>true)
        capture_stderr { load('blah', :no_mock=>true).should == false }.should == ''
      end

      test "loads and strips aliases from a library's commands" do
        with_config(:commands=>{"blah"=>{:alias=>'b'}}) do
          load :blah, :file_string=>"module Blah; def blah; end; alias_method(:b, :blah); end"
          Library.loaded?('blah').should == true
          library('blah')[:commands].should == ['blah']
        end
      end

      test "loads a file library in a subdirectory" do
        load 'site/delicious', :file_string=>"module Delicious; def blah; end; end"
        library_has_module('site/delicious', "Boson::Libraries::Delicious")
        command_exists?('blah').should == true
      end

      test "loads a monkeypatched gem" do
        load "dude", :file_string=>"module ::Kernel; def dude; end; end", :gem=>true
        Library.loaded?("dude").should == true
        library('dude')[:module].should == nil
        command_exists?("dude").should == true
      end

      test "loads a normal gem" do
        with_config(:libraries=>{"dude"=>{:module=>'Dude'}}) do
          load "dude", :file_string=>"module ::Dude; def blah; end; end", :gem=>true
          library_has_module('dude', "Dude")
          command_exists?("blah").should == true
        end
      end

      test "loads a library with dependencies" do
        File.stubs(:exists?).returns(true)
        File.stubs(:read).returns("module Oaks; def oaks; end; end", "module Water; def water; end; end")
        with_config(:libraries=>{"water"=>{:dependencies=>"oaks"}}) do
          Library.load ['water']
          library_has_module('water', "Boson::Libraries::Water")
          library_has_module('oaks', "Boson::Libraries::Oaks")
          command_exists?('water').should == true
          command_exists?('oaks').should == true
        end
      end

      test "prints error for library with invalid dependencies" do
        with_config(:libraries=>{"water"=>{:dependencies=>"fire"}, "fire"=>{:dependencies=>"man"}}) do
          capture_stderr { 
            load('water', :no_mock=>true)
          }.should == "Unable to load library fire. Reason: Can't load dependency man\nUnable to load"+
          " library water. Reason: Can't load dependency fire\n"
        end
      end

      test "prints error for library with method conflicts" do
        load('chwhat', :file_string=>"module Chwhat; def chwhat; end; end")
        capture_stderr {
          load('chwhat2', :file_string=>"module Chwhat2; def chwhat; end; end")
        }.should =~ /Unable to load library chwhat2.*conflict.*chwhat/
      end

      test "prints error for library with invalid module" do
        with_config(:libraries=>{"coolio"=>{:module=>"Cool"}}) do
          capture_stderr {
            load('coolio', :gem=>true, :file_string=>"module ::Coolio; def coolio; end; end")
          }.should =~ /Unable.*coolio.*Module Cool/
        end
      end
    end

    context "reload_library" do
      test "reloads file library with same module" do
        load(:blah, :file_string=>"module Blah; def blah; end; end")
        File.stubs(:exists?).returns(true)
        File.stubs(:read).returns("module Blah; def bling; end; end")
        Loader.reload_library('blah')
        command_exists?('bling').should == true
      end

      test "reloads file library with different module" do
        load(:blah, :file_string=>"module Blah; def blah; end; end")
        File.stubs(:exists?).returns(true)
        File.stubs(:read).returns("module Bling; def bling; end; end")
        Loader.reload_library('blah')
        library_has_module('blah', "Boson::Libraries::Bling")
        command_exists?('bling').should == true
        command_exists?('blah').should == false
      end
    end
  end
end