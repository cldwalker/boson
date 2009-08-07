require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LoaderTest < Test::Unit::TestCase
    def load(lib, options={})
      unless lib.is_a?(Module)
        File.expects(:exists?).with(Loader.library_file(lib.to_s)).returns(true)
        File.expects(:read).returns(options.delete(:file_string))
      end
      Library.load([lib], options)
    end

    def library(name)
      Boson.libraries.find_by(:name=>name)
    end

    context "create" do
      #resets lib_config
    end

    context "load_and_create" do
      def library_has_module(lib, lib_module)
        Library.loaded?(lib).should == true
        test_lib = library(lib)
        (test_lib[:module].is_a?(Module) && (test_lib[:module].to_s == lib_module)).should == true
      end

      before(:each) { reset_libraries; reset_commands }
      test "loads a module" do
        eval %[module ::Harvey; def bird; end; end]
        load ::Harvey
        library_has_module('harvey', "Harvey")
        command_exists?('bird').should == true
      end

      test "loads a basic library" do
        capture_stdout {
          load :blah, :file_string=>"module Blah; def self.included(mod); puts 'included blah'; end; def blah; end; end"
        }.should =~ /included blah/
        library_has_module('blah', 'Boson::Libraries::Blah')
        command_exists?('blah').should == true
      end

      test "loads and strips aliases from a lib's commands" do
        with_config(:commands=>{"blah2"=>{:alias=>'b2'}}) do
          load :blah, :file_string=>"module Blah2; def blah2; end; alias_method(:b2, :blah2); end"
          Library.loaded?('blah').should == true
          library('blah')[:commands].should == ['blah2']
        end
      end

      test "loads a library in a subdirectory" do
        load 'site/delicious', :file_string=>"module Delicious; def bundles; end; end"
        library_has_module('site/delicious', "Boson::Libraries::Delicious")
        command_exists?('bundles').should == true
      end

      test "loads a monkeypatched gem" do
        File.expects(:exists?).returns(false)
        Util.expects(:safe_require).with { eval "module ::Kernel; def dude; end; end"; true}.returns(true)
        Library.load ["dude"]
        Library.loaded?("dude").should == true
        library('dude')[:module].should == nil
        command_exists?("dude").should == true
      end

      test "loads a normal gem" do
        File.expects(:exists?).returns(false)
        Util.expects(:safe_require).with { eval "module ::Dude2; def dude2; end; end"; true}.returns(true)
        with_config(:libraries=>{"dude2"=>{:module=>'Dude2'}}) do
          Library.load ["dude2"]
          library_has_module('dude2', "Dude2")
          command_exists?("dude2").should == true
        end
      end

      # load lib w/ deps
      # method conflicts
      # :object_commands
      # :call_methods
      # :no_module_eval/:module
      # :force
      #resets lib_config
    end
    # *Error
  end
end