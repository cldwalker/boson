require File.join(File.dirname(__FILE__), 'test_helper')

class Boson::RepoTest < Test::Unit::TestCase
  context "config" do
    before(:all) { reset }
    before(:each) { @repo = Boson::Repo.new(File.dirname(__FILE__)) }

    test "reloads config when passed true" do
      @repo.config.object_id.should_not == @repo.config(true).object_id
    end

    test "reads existing config correctly" do
      expected_hash = {:commands=>{'c1'=>{}}, :libraries=>{}}
      YAML.expects(:load_file).returns(expected_hash)
      @repo.config[:commands]['c1'].should == {}
    end

    test "ignores nonexistent file and sets config defaults" do
      assert @repo.config[:commands].is_a?(Hash) && @repo.config[:libraries].is_a?(Hash)
    end
  end
end
