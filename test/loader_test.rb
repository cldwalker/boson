require File.join(File.dirname(__FILE__), 'test_helper')

describe "Loader" do
  describe "load" do
    before { reset }

    it "prints error for method conflicts with main_object method" do
      runner = create_runner :require
      capture_stderr {
        Manager.load runner
      }.should =~ /Unable to load library Blarg.*conflict.*commands: require/
    end

    it "prints error for method conflicts between libraries" do
      create_runner :whoops
      create_runner :whoops, library: :Blorg
      Manager.load Blarg
      capture_stderr {
        Manager.load Blorg
      }.should =~ /Unable to load library Blorg.*conflict.*commands: whoops/
    end

    it "prints error for library that's already loaded" do
      runner = create_runner
      Manager.load runner
      capture_stderr {
        Manager.load runner, verbose: true
      }.should =~ /blarg already exists/
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
