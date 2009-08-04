require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class ManagerTest < Test::Unit::TestCase

  context "activate" do
    def activate(*args)
      Boson.activate(*args)
    end

    before(:each) { reset_boson }

    # td: fake Util.detect_methods in Util.detect once it knows about current lib_module
    # test "creates default libraries and commands" do
    #   activate
    #   assert Boson.libraries.map {|e| e[:name]}.select {|e| e.include?('boson')}.size >= 2
    #   assert_equal Boson.commands.map {|e| e.name}.sort, Boson::Libraries::Core.instance_methods.map {|e| e.to_s}.sort
    # end

    test "adds dir to $LOAD_PATH" do
      activate
      assert $LOAD_PATH.include?(Boson.dir)
    end

    test "main_object responds to commands" do
      activate
      assert Boson.commands.map {|e| e.name }.all? {|e| Boson.main_object.respond_to?(e)}
    end

    test "loads default irb library when irb exists" do
      eval %[module ::IRB; module ExtendCommandBundle; end; end]
      activate
      assert Boson.libraries.any? {|e| e[:module] == IRB::ExtendCommandBundle}
      IRB.send :remove_const, "ExtendCommandBundle"
    end

    test "creates libraries under :dir/libraries/" do
      Dir.stubs(:[]).returns(['./libraries/lib.rb', './libraries/lib2.rb'])
      Library.expects(:create).with(['lib', 'lib2'], anything)
      activate
    end

    test "creates libraries in :libraries config" do
      Boson.config[:libraries] = {'yada'=>{:detect_methods=>false}}
      Library.expects(:create).with(['yada'], anything)
      activate
      Boson.config[:libraries] = {}
    end

    test "loads libraries in :defaults config" do
      Boson.config[:defaults] = ['yo']
      Library.stubs(:load).with {|*args| args[0].empty? ? true : args[0].include?('yo') }
      activate
      Boson.config.delete(:defaults)
    end

    test "doesn't call init twice" do
      activate
      Manager.expects(:init).never
      activate
    end

    test "loads multiple libraries with :libraries option" do
      Manager.expects(:init)
      Library.expects(:load).with([:lib1,:lib2], anything)
      activate(:libraries=>[:lib1, :lib2])
    end
  end
  end
end
