require File.join(File.dirname(__FILE__), 'test_helper')

describe "config" do
  before_all { reset }
  before { @repo = Repo.new(File.dirname(__FILE__)) }

  it "reloads config when passed true" do
    @repo.config.object_id.should.not == @repo.config(true).object_id
  end

  it "reads existing config correctly" do
    expected_hash = {:commands=>{'c1'=>{}}, :libraries=>{}}
    File.expects(:exists?).returns(true)
    YAML.expects(:load_file).returns(expected_hash)
    @repo.config[:commands]['c1'].should == {}
  end

  it "ignores nonexistent file and sets config defaults" do
    @repo.config[:command_aliases].class.should == Hash
    @repo.config[:libraries].class.should == Hash
  end
  after_all { FileUtils.rm_r File.dirname(__FILE__)+'/config', :force=>true }
end