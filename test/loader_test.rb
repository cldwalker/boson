require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LoaderTest < Test::Unit::TestCase

    context "load" do
      before(:each) { reset_main_object; reset_libraries; reset_commands }
      test "calls included hook" do
        capture_stdout {
          load :blah, :file_string=>"module Blah; def self.included(mod); puts 'included blah'; end; def blah; end; end"
        }.should =~ /included blah/
      end

      test "calls methods in config call_methods" do
        with_config(:libraries=>{"blah"=>{:call_methods=>['blah']}}) do
          capture_stdout {
            load :blah, :file_string=>"module Blah; def blah; puts 'yo'; end; end"
          }.should == "yo\n"
        end
      end

      test "prints error and returns false for existing library" do
        lib = Library.new(:name=>'blah', :loaded=>true)
        Boson.libraries << lib
        Library.stubs(:loader_create).returns(lib)
        capture_stderr { load('blah', :no_mock=>true, :verbose=>true).should == false }.should =~ /already exists/
      end

      test "loads and strips aliases from a library's commands" do
        with_config(:commands=>{"blah"=>{:alias=>'b'}}) do
          load :blah, :file_string=>"module Blah; def blah; end; alias_method(:b, :blah); end"
          library_loaded?('blah')
          library('blah').commands.should == ['blah']
        end
      end

      test "loads a library with dependencies" do
        File.stubs(:exists?).returns(true)
        File.stubs(:read).returns("module Oaks; def oaks; end; end", "module Water; def water; end; end")
        with_config(:libraries=>{"water"=>{:dependencies=>"oaks"}}) do
          load 'water', :no_mock=>true
          library_has_module('water', "Boson::Commands::Water")
          library_has_module('oaks', "Boson::Commands::Oaks")
          command_exists?('water')
          command_exists?('oaks')
        end
      end

      test "prints error for library with invalid dependencies" do
        GemLibrary.stubs(:is_a_gem?).returns(true) #mock all as gem libs
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
      context "module library" do
        def mock_library(*args); end

        test "loads a module library" do
          eval %[module ::Harvey; def bird; end; end]
          load ::Harvey, :no_mock=>true
          library_has_module('harvey', "Harvey")
          command_exists?('bird')
        end
      end

      context "gem library" do
        def mock_library(lib, options={})
          options[:file_string] ||= ''
          File.expects(:exists?).returns(false)
          GemLibrary.expects(:is_a_gem?).returns(true)
          Util.expects(:safe_require).with { eval options.delete(:file_string) || ''; true}.returns(true)
        end

        test "loads" do
          with_config(:libraries=>{"dude"=>{:module=>'Dude'}}) do
            load "dude", :file_string=>"module ::Dude; def blah; end; end"
            library_has_module('dude', "Dude")
            command_exists?("blah")
          end
        end

        test "with kernel methods loads" do
          load "dude", :file_string=>"module ::Kernel; def dude; end; end"
          library_loaded? 'dude'
          library('dude').module.should == nil
          command_exists?("dude")
        end

        test "prints error when nonexistent" do
          capture_stderr { load('blah') }.should =~ /Unable.*load/
        end

        test "with invalid module prints error" do
          with_config(:libraries=>{"coolio"=>{:module=>"Cool"}}) do
            capture_stderr {
              load('coolio', :file_string=>"module ::Coolio; def coolio; end; end")
            }.should =~ /Unable.*coolio.*Module Cool/
          end
        end
      end
    end

    context "namespace_command" do
      before(:all) {
        reset_main_object
        $".delete('boson/commands/namespace.rb') && require('boson/commands/namespace.rb')
        reset_libraries; Library.load([Boson::Commands::Namespace])
      }
      before(:each) { reset_commands }

      test "creates and defaults to library name" do
        with_config(:libraries=>{'blang'=>{:namespace=>true}}) do
          load 'blang', :file_string=>"module Blang; def bling; end; end"
          library_has_command('namespace', 'blang')
          library_has_command('blang', 'bling')
        end
      end

      test "creates with namespace_config" do
        with_config(:libraries=>{'blung'=>{:namespace=>'dope'}}) do
          load 'blung', :file_string=>"module Blung; def bling; end; end"
          library_has_command('namespace', 'dope')
          library_has_command('blung', 'bling')
          library('blung').commands.size.should == 1
        end
      end
    end

    context "reload_library" do
      before(:each) { reset_main_object; reset_libraries; reset_commands }
      test "loads currently unloaded library" do
        Library.create(['blah'])
        Library.expects(:load_library).with('blah', anything)
        Library.reload_library('blah')
      end

      test "doesn't load nonexistent library" do
        capture_stdout { Library.reload_library('bling', :verbose=>true) }.should =~ /bling doesn't/
      end
    end
  end
end
