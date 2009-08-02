require File.join(File.dirname(__FILE__), 'test_helper')

class BosonTest < Test::Unit::TestCase
  context "config" do
    before(:all) { reset_boson; Boson.activate }
    before(:each) { Boson.instance_variable_set("@config", nil) }

    test "reloads config when passed true" do
      Boson.config.object_id.should_not == Boson.config(true).object_id
    end

    test "reads existing config correctly" do
      expected_hash = {:commands=>{'c1'=>{}}, :libraries=>{}}
      YAML.expects(:load_file).returns(expected_hash)
      Boson.config.should == expected_hash
    end

    test "ignores nonexistent file and sets config defaults" do
      assert Boson.config[:commands].is_a?(Hash) && Boson.config[:libraries].is_a?(Hash)
    end
  end
end
