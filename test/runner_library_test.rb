require File.join(File.dirname(__FILE__), 'test_helper')

describe "RunnerLibrary" do
  before { reset }

  it "creates a library with correct commands" do
    Manager.load create_runner(:blah)
    library('blarg').commands.should == ['blah']
  end
end
