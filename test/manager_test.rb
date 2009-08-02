require File.join(File.dirname(__FILE__), 'test_helper')

class Boson::ManagerTest < Test::Unit::TestCase
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