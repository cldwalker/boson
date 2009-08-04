require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class ManagerTest < Test::Unit::TestCase

  context "activate" do
    def activate(*args)
      Boson.activate(*args)
    end

    before(:each) { reset_boson }

    # td: fix
    #test "creates default libraries and commands" do
      #activate
      #assert Boson.libraries.map {|e| e[:name]}.select {|e| e.include?('boson')}.size >= 2
      #(Boson::Libraries::Core.instance_methods - Boson.commands.map {|e| e[:name]}).empty?.should be(true)
    #end

    test "adds dir to $LOAD_PATH" do
      activate
      assert $LOAD_PATH.include?(Boson.dir)
    end

    test "main_object responds to commands" do
      activate
      assert Boson.commands.map {|e| e[:name]}.all? {|e| Boson.main_object.respond_to?(e)}
    end

    test "loads default irb library when irb exists" do
      eval %[module ::IRB; module ExtendCommandBundle; end; end]
      activate
      assert Boson.libraries.any? {|e| e[:module] == IRB::ExtendCommandBundle}
      IRB.send :remove_const, "ExtendCommandBundle"
    end

    test "creates libraries under :dir/libraries/" do
      Dir.stubs(:[]).returns(['./libraries/lib.rb', './libraries/lib2.rb'])
      Manager.expects(:create_libraries).with(['lib', 'lib2'], anything)
      activate
    end

    test "creates libraries in config[:libraries]" do
      Boson.config[:libraries] = {'yada'=>{:detect_methods=>false}}
      Manager.expects(:create_libraries).with(['yada'], anything)
      activate
      Boson.config[:libraries] = {}
    end

    test "loads libraries in config[:defaults]" do
      Boson.config[:defaults] = ['yo']
      Manager.stubs(:load_libraries).with {|*args| args[0].empty? ? true : args[0].include?('yo') }
      activate
      Boson.config.delete(:defaults)
    end

    test "doesn't call init twice" do
      activate
      Manager.expects(:init).never
      activate
    end

    test "loads multiple libraries" do
      Manager.expects(:init)
      Manager.expects(:load_libraries).with([:lib1,:lib2], anything)
      activate(:libraries=>[:lib1, :lib2])
    end
  end

  def reset_libraries
    Boson.instance_eval("@libraries = Boson::SearchableArray.new")
  end

  context "load_libraries" do
    before(:each) { reset_libraries; Boson.config[:libraries] = {}}
    # test "loads and creates multiple basic libraries" do
    #   Boson::Manager.stubs(:load).returns(true)
    #   Boson::Manager.load_libraries(['blah'])
    #   Boson.libraries.find_by(:name=>'blah').size.should == 1
    #   Boson.libraries.find_by(:name=>'blah')[:loaded].should be(true)
    # end
    # adds lib: add or update
    # adds lib commands: only when loaded, lib except option, aliases (module + no module)
    # adds lib deps
  end

  context "create_libraries" do
    before(:each) { reset_libraries }
    test "creates basic library" do
      Boson.config[:libraries] = {'blah'=>{:dependencies=>['bluh']}}
      Boson::Manager.create_libraries(['blah'])
      Boson.libraries.find_by(:name=>'blah').is_a?(Boson::Library).should be(true)
      Boson.libraries.find_by(:name=>'blah')[:dependencies].should == ['bluh']
      Boson.config[:libraries] = {}
    end

    test "doesn't create two libraries with same name" do
      Boson::Manager.create_libraries(['doh'])
      Boson::Manager.create_libraries(['doh'])
      Boson.libraries.size.should == 1
    end
  end

  context "library_loaded" do
    before(:each) { reset_libraries }
    after(:each) { Boson.config[:libraries] = {}}
  
    test "returns false when library isn't loaded" do
      Boson.config[:libraries] = {'blah'=>{:loaded=>false}}
      Boson::Manager.create_libraries(['blah'])
      Boson::Manager.library_loaded?('blah').should be(false)
    end

    test "returns true when library is loaded" do
      Boson.config[:libraries] = {'blah'=>{:loaded=>true}}
      Boson::Manager.create_libraries(['blah'])
      Boson::Manager.library_loaded?('blah').should be(true)
    end
  end
  end
end
