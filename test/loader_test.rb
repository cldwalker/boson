require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LoaderTest < Test::Unit::TestCase

    def load_namespace_library
      Library.load([Boson::Commands::Namespace])
    end

    context "load" do
      before(:each) { reset }
      test "calls included hook" do
        capture_stdout {
          load :blah, :file_string=>"module Blah; def self.included(mod); puts 'included blah'; end; def blah; end; end"
        }.should =~ /included blah/
      end

      test "calls methods in config init_methods" do
        with_config(:libraries=>{"blah"=>{:init_methods=>['blah']}}) do
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

      test "prints error for method conflicts with config error_method_conflicts" do
        with_config(:error_method_conflicts=>true) do
          load('blah', :file_string=>"module Blah; def chwhat; end; end")
          capture_stderr {
            load('chwhat', :file_string=>"module Chwhat; def chwhat; end; end")
          }.should =~ /Unable to load library chwhat.*conflict.*chwhat/
        end
      end

      test "namespaces a library that has a method conflict" do
        load_namespace_library
        load('blah', :file_string=>"module Blah; def chwhat; end; end")
        capture_stderr {
          load('chwhat2', :file_string=>"module Chwhat2; def chwhat; end; end")
        }.should =~ /Unable.*chwhat2/
        library_has_command('namespace', 'chwhat2')
        library_has_command('chwhat2', 'chwhat')
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
            }.should =~ /Unable.*coolio.*No module/
          end
        end
      end
    end

    context "library with namespace" do
      before(:all) { reset_main_object; load_namespace_library }
      before(:each) { reset_boson }

      test "loads and defaults to library name" do
        with_config(:libraries=>{'blang'=>{:namespace=>true}}) do
          load 'blang', :file_string=>"module Blang; def bling; end; end"
          library_has_command('namespace', 'blang')
          library_has_command('blang', 'bling')
        end
      end

      test "loads with config namespace" do
        with_config(:libraries=>{'blung'=>{:namespace=>'dope'}}) do
          load 'blung', :file_string=>"module Blung; def bling; end; end"
          library_has_command('namespace', 'dope')
          library_has_command('blung', 'bling')
          library('blung').commands.size.should == 1
        end
      end

      test "loads with config except" do
        with_config(:libraries=>{'blong'=>{:namespace=>true, :except=>['blong']}}) do
          load 'blong', :file_string=>"module Blong; def bling; end; def blong; end; end"
          library_has_command('namespace', 'blong')
          library_has_command('blong', 'bling')
          library_has_command('blong', 'blong', false)
          library('blong').commands.size.should == 1
        end
      end

      test "prints error if namespace conflicts with existing commands" do
        eval "module Conflict; def bleng; end; end"
        load Conflict, :no_mock=>true
        with_config(:libraries=>{'bleng'=>{:namespace=>true}}) do
          capture_stderr {
            load 'bleng', :file_string=>"module Bleng; def bling; end; end"
          }.should =~ /conflict.*bleng/
        end
      end
    end

    context "reload_library" do
      before(:each) { reset }
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
