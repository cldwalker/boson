require File.join(File.dirname(__FILE__), 'test_helper')

class BosonTest < Test::Unit::TestCase
  def reset_init
    Boson.instance_variables.each do |e|
      Boson.instance_variable_set(e, nil)
    end
    Boson.send :remove_const, "Libraries"
    eval "module ::Boson::Libraries; end"
  end

  def boson_init(options={})
    Boson.init({:base_dir=>'.'}.update(options))
  end

  context "basic init" do
    before(:all) { boson_init }
    after(:all) { reset_init }

    test "sets init_called" do
      assert Boson.init_called?
    end

    test "creates default libraries and commands" do
      assert Boson.libraries.map {|e| e[:name]}.select {|e| e.include?('boson')}.size >= 2
      (Boson::Commands.instance_methods - Boson.commands.map {|e| e[:name]}).empty?.should be(true)
    end

    test "creates base_object" do
      Boson.base_object.should_not be(nil)
    end

    test "adds base_dir to $LOAD_PATH" do
      assert $LOAD_PATH.include?(Boson.base_dir)
    end

    test "base_object responds to commands" do
      assert Boson.commands.map {|e| e[:name]}.all? {|e| Boson.base_object.respond_to?(e)}
    end
  end

  context "init" do
    after(:each) { reset_init }
    test "loads default irb library when irb exists" do
      eval %[module ::IRB; module ExtendCommandBundle; end; end]
      boson_init
      assert Boson.libraries.any? {|e| e[:module] == IRB::ExtendCommandBundle}
      IRB.send :remove_const, "ExtendCommandBundle"
    end

    test "sets base dir with :base_dir option" do
      boson_init :base_dir=>"some_dir"
      Boson.base_dir.should == File.expand_path("some_dir")
    end

    test "sets base_object with :with option" do
      obj = Object.new
      boson_init :with=>obj
      Boson.base_object.should == obj
    end

    test "creates libraries under :base_dir/libraries/" do
      Dir.stubs(:[]).returns(['./libraries/lib.rb', './libraries/lib2.rb'])
      Boson::Manager.expects(:create_libraries).with(['lib', 'lib2'], anything)
      boson_init
    end

    test "creates libraries in config[:defaults]" do
      Boson.config[:defaults] = ['yo']
      Boson::Manager.expects(:load_libraries).with {|args| args.include?('yo') }
      boson_init
      Boson.config.delete(:defaults)
    end
  end

  context "register" do
    test "doesn't call init twice" do
      Boson.register(:base_dir=>'.')
      Boson.expects(:init).never
      Boson.register
    end

    test "loads multiple libraries" do
      Boson::Manager.expects(:load_libraries).with([:lib1,:lib2])
      Boson.register(:lib1, :lib2, :base_dir=>'.')
    end
  end

  # context "config" do
  #   test "reloads when passed true"
  #   test "reads existing config correctly"
  #   test "ignores nonexistent file and sets config defaults"
  # end
end
