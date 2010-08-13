require File.join(File.dirname(__FILE__), 'test_helper')

describe "Command" do
  describe ".find" do
    before_all {
      reset_boson
      Boson.libraries << Library.new(:name=>'bling', :namespace=>true)
      @namespace_command = Command.new(:name=>'blah', :lib=>'bling', :namespace=>'bling')
      @top_level_command = Command.new(:name=>'blah', :lib=>'bling')
      Boson.commands << @namespace_command
      Boson.commands << @top_level_command
    }

    it 'finds correct command when a subcommand of the same name exists' do
      Command.find('blah').should == @top_level_command
    end

    it 'finds correct command when a top level command of the same name exists' do
      Command.find('bling.blah').should == @namespace_command
    end
  end
end
