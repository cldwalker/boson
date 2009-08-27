require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class RunnerTest < Test::Unit::TestCase

  context "activate" do
    before(:each) { reset_boson }

    # td: fake Util.detect_methods in Util.detect once it knows about current lib_module
    # test "creates default libraries and commands" do
    #   activate
    #   assert Boson.libraries.map {|e| e[:name]}.select {|e| e.include?('boson')}.size >= 2
    #   assert_equal Boson.commands.map {|e| e.name}.sort, Boson::Commands::Core.instance_methods.map {|e| e.to_s}.sort
    # end

    test "main_object responds to commands" do
      activate
      assert Boson.commands.map {|e| e.name }.all? {|e| Boson.main_object.respond_to?(e)}
    end

    test "loads default irb library when irb exists" do
      eval %[module ::IRB; module ExtendCommandBundle; end; end]
      activate
      assert Boson.libraries.any? {|e| e.module == IRB::ExtendCommandBundle}
      IRB.send :remove_const, "ExtendCommandBundle"
    end

    test "creates libraries under :dir/libraries/" do
      Dir.stubs(:[]).returns(['./commands/lib.rb', './commands/lib2.rb'])
      Library.expects(:create).with(['lib', 'lib2'], anything)
      activate
    end

    test "creates libraries in :libraries config" do
      with_config :libraries=>{'yada'=>{:detect_methods=>false}} do
        Library.expects(:create).with(['yada'], anything)
        activate
      end
    end

    test "loads libraries in :defaults config" do
      with_config(:defaults=>['yo']) do
        Library.stubs(:load).with {|*args| args[0].empty? ? true : args[0].include?('yo') }
        activate
      end
    end

    test "doesn't call init twice" do
      activate
      Runner.expects(:init).never
      activate
    end

    test "loads multiple libraries with :libraries option" do
      Runner.expects(:init)
      Library.expects(:load).with([:lib1,:lib2], anything)
      activate(:libraries=>[:lib1, :lib2])
    end
  end
  end
end
