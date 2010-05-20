require File.join(File.dirname(__FILE__), 'test_helper')

context "config" do
  before_all { reset }
  before { @repo = Boson::Repo.new(File.dirname(__FILE__)) }

  test "reloads config when passed true" do
    @repo.config.object_id.should.not == @repo.config(true).object_id
  end

  test "reads existing config correctly" do
    expected_hash = {:commands=>{'c1'=>{}}, :libraries=>{}}
    File.expects(:exists?).returns(true)
    YAML.expects(:load_file).returns(expected_hash)
    @repo.config[:commands]['c1'].should == {}
  end

  test "ignores nonexistent file and sets config defaults" do
    @repo.config[:command_aliases].class.should == Hash
    @repo.config[:libraries].class.should == Hash
  end
end