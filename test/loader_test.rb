require File.join(File.dirname(__FILE__), 'test_helper')

describe "Loader" do
  describe "load" do
    before { reset }

    it "prints error for method conflicts with main_object method" do
      runner = create_runner :require
      manager_load runner
      stderr.should =~ /Unable to load library Blarg.*conflict.*commands: require/
    end

    it "prints error for method conflicts between libraries" do
      create_runner :whoops
      create_runner :whoops, library: :Blorg
      Manager.load Blarg
      manager_load Blorg
      stderr.should =~ /^Unable to load library Blorg.*conflict.*commands: whoops/
    end

    it "sets loaded to true after loading a library" do
      Manager.load create_runner
      library('blarg').loaded.should == true
    end

    it "loads and strips aliases from a library's commands" do
      with_config(:command_aliases=>{"blah"=>'b'}) do
        runner = create_runner do
          def blah; end
          alias :b :blah
        end
        Manager.load runner
        library('blarg').commands.should == ['blah']
      end
    end
  end
end
