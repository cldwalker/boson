require File.join(File.dirname(__FILE__), 'test_helper')
require 'boson/runners/bin_runner'

module Boson
  class BinRunnerTest < Test::Unit::TestCase
    def start(*args)
      Hirb.stubs(:enable)
      BinRunner.start(args)
    end

    before(:each) {|e|
      Boson::BinRunner.instance_variables.each {|e| Boson::BinRunner.instance_variable_set(e, nil)}
    }
    context "bin_runner" do
      before(:all) { reset }

      test "with no arguments prints usage" do
        capture_stdout { start }.should =~ /^boson/
      end

      test "with option but no arguments prints usage" do
        capture_stdout { start '-v' }.should =~ /^boson/
      end

      test "with undiscovered command prints error" do
         BinRunner.expects(:load_command_by_index).returns(false)
        capture_stderr { start('blah') }.should =~ /Error.*blah/
      end

      test "executes basic command" do
        BinRunner.expects(:init).returns(true)
        BinRunner.stubs(:render_output)
        Boson.main_object.expects(:send).with('kick','it')
        start 'kick','it'
      end

      test "executes sub command" do
        obj = Object.new
        Boson.main_object.extend Module.new { def phone; Struct.new(:home).new('done'); end }
        BinRunner.expects(:init).returns(true)
        BinRunner.expects(:render_output).with('done')
        start 'phone.home'
      end
    end

    context "load_command_by_index" do
      test "with index option, no existing index and core command updates index and prints index message" do
        Library.expects(:load).with {|*args| args[0][0].is_a?(Module) ? true : args[0] == Runner.all_libraries }.times(2)
        Index.expects(:exists?).returns(false)
        Index.expects(:write)
        capture_stdout { start("--index", "libraries") }.should =~ /Generating index/
      end

      test "with index option, existing index and core command updates incremental index" do
        Index.expects(:changed_libraries).returns(['changed'])
        Library.expects(:load).with {|*args| args[0][0].is_a?(Module) ? true : args[0] == ['changed'] }.times(2)
        Index.expects(:exists?).returns(true)
        Index.expects(:write)
        capture_stdout { start("--index", "libraries")}.should =~ /Indexing.*changed/
      end

      test "with core command updates index and doesn't print index message" do
        Index.expects(:write)
        Boson.main_object.expects(:send).with('libraries')
        capture_stdout { start 'libraries'}.should == ''
      end

      test "with non-core command finding library doesn't update index" do
        Index.expects(:find_library).returns('sweet_lib')
        Library.expects(:load_library).with {|*args| args[0].is_a?(String) ? args[0] == 'sweet_lib' : true}.at_least(1)
        Index.expects(:update).never
        capture_stderr { start("sweet") }.should =~ /sweet/
      end

      test "with non-core command not finding library, does update index" do
        Index.expects(:find_library).returns(nil, 'sweet_lib').times(2)
        Library.expects(:load_library).with {|*args| args[0].is_a?(String) ? args[0] == 'sweet_lib' : true}.at_least(1)
        Index.expects(:update).returns(true)
        capture_stderr { start("sweet") }.should =~ /sweet/
      end
    end

    test "parse_args only translates options before command" do
      BinRunner.parse_args(['-v', 'com', '-v']).should == ["com", {:verbose=>true}, ['-v']]
      BinRunner.parse_args(['com', '-v']).should == ["com", {}, ['-v']]
    end
  end
end