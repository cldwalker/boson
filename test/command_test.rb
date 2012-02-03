require File.join(File.dirname(__FILE__), 'test_helper')

describe "Command" do
  describe ".find" do
    before do
      reset_boson
      @top_level_command = create_command(:name=>'blah', :lib=>'bling')
    end

    it 'finds correct command when a subcommand of the same name exists' do
      Command.find('blah').should == @top_level_command
    end

    it 'finds nothing given nil' do
      Command.find(nil).should == nil
    end
  end
end
