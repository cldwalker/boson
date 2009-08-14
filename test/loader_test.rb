require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LoaderTest < Test::Unit::TestCase
    def load(lib, options={})
      unless lib.is_a?(Module) || options.delete(:no_mock)
        options[:file_string] ||= ''
        if options.delete(:gem)
          File.expects(:exists?).returns(false)
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
      Library.load([lib], options)
    end

    def library(name)
      Boson.libraries.find_by(:name=>name)
    end

    context "load_and_create" do
      def library_has_module(lib, lib_module)
        Library.loaded?(lib).should == true
        test_lib = library(lib)
        (test_lib[:module].is_a?(Module) && (test_lib[:module].to_s == lib_module)).should == true
      end

      before(:each) { reset_libraries; reset_commands }
      test "loads a module library" do
        eval %[module ::Harvey; def bird; end; end]
        load ::Harvey
        library_has_module('harvey', "Harvey")
        command_exists?('bird').should == true
      end

      test "loads a file library" do
        capture_stdout {
          load :blah, :file_string=>"module Blah; def self.included(mod); puts 'included blah'; end; def blah; end; end"
        }.should =~ /included blah/
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
        with_config(:libraries=>{"cool"=>{:no_module_eval=>true}}) do
          load :cool, :file_string=>"module Boson::Libraries::Cool; def cool; end; end", :no_module_eval=>true
        end
        library_has_module('cool', 'Boson::Libraries::Cool')
        command_exists?('cool').should == true
      end

      test "prints error for invalid library" do
        capture_stderr { load('blah', :gem=>true) }.should =~ /Unable.*load/
      end

      test "returns false for existing library" do
        Boson.libraries << Library.new(:name=>'blah', :loaded=>true)
        capture_stderr { load('blah', :no_mock=>true).should == false }.should == ''
      end

      test "loads and strips aliases from a library's commands" do
        with_config(:commands=>{"blah2"=>{:alias=>'b2'}}) do
          load :blah, :file_string=>"module Blah2; def blah2; end; alias_method(:b2, :blah2); end"
          Library.loaded?('blah').should == true
          library('blah')[:commands].should == ['blah2']
        end
      end

      test "loads a file library in a subdirectory" do
        load 'site/delicious', :file_string=>"module Delicious; def bundles; end; end"
        library_has_module('site/delicious', "Boson::Libraries::Delicious")
        command_exists?('bundles').should == true
      end

      test "loads a monkeypatched gem" do
        load "dude", :file_string=>"module ::Kernel; def dude; end; end", :gem=>true
        Library.loaded?("dude").should == true
        library('dude')[:module].should == nil
        command_exists?("dude").should == true
      end

      test "loads a normal gem" do
        with_config(:libraries=>{"dude2"=>{:module=>'Dude2'}}) do
          load "dude2", :file_string=>"module ::Dude2; def dude2; end; end", :gem=>true
          library_has_module('dude2', "Dude2")
          command_exists?("dude2").should == true
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
  end
end