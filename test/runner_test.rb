require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class RunnerTest < Test::Unit::TestCase
    context "repl_runner" do
      before(:all) { reload_commands }
      before(:each) { reset_boson; Boson::ReplRunner.instance_eval("@initialized = false") }

      test "loads default irb library when irb exists" do
        eval %[module ::IRB; module ExtendCommandBundle; end; end]
        Library.expects(:load).with {|*args| args[0].include?(IRB::ExtendCommandBundle) }
        activate
        IRB.send :remove_const, "ExtendCommandBundle"
      end

      test "loads default libraries and libraries in :defaults config" do
        defaults = Boson::Runner.boson_libraries + ['yo']
        with_config(:defaults=>['yo']) do
          Library.expects(:load).with {|*args| args[0] == defaults }
          activate
        end
      end

      test "doesn't call init twice" do
        activate
        ReplRunner.expects(:init).never
        activate
      end

      test "loads multiple libraries with :libraries option" do
        ReplRunner.expects(:init)
        Library.expects(:load).with([:lib1,:lib2], anything)
        activate(:libraries=>[:lib1, :lib2])
      end
    end
  end
end