require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class RunnerTest < Test::Unit::TestCase
    context "repl_runner" do
      def start(*args)
        Hirb.stubs(:enable)
        Boson.start(*args)
      end

      before(:all) { reset }
      before(:each) { Boson::ReplRunner.instance_eval("@initialized = false") }

      test "loads default libraries and libraries in :defaults config" do
        defaults = Boson::Runner.default_libraries + ['yo']
        with_config(:defaults=>['yo']) do
          Manager.expects(:load).with {|*args| args[0] == defaults }
          start
        end
      end

      test "doesn't call init twice" do
        start
        ReplRunner.expects(:init).never
        start
      end

      test "loads multiple libraries with :libraries option" do
        ReplRunner.expects(:init)
        Manager.expects(:load).with([:lib1,:lib2], anything)
        start(:libraries=>[:lib1, :lib2])
      end

      test "autoloader autoloads libraries" do
        start(:autoload_libraries=>true)
        Index.expects(:read)
        Index.expects(:find_library).with('blah').returns('blah')
        Manager.expects(:load).with('blah', :verbose=>true)
        Boson.main_object.blah
      end
    end
  end
end