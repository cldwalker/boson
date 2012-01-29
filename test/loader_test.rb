require File.join(File.dirname(__FILE__), 'test_helper')

describe "Loader" do
  describe "load" do
    before { reset }

    it "prints error for method conflicts with main_object method" do
      create_runner :require
      capture_stderr {
        Manager.load Blarg
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
      create_runner :blah
      Manager.load Blarg
      capture_stderr {
        Manager.load Blarg, verbose: true
      }.should =~ /blarg already exists/
    end
  end
end
__END__
    it "loads and strips aliases from a library's commands" do
      with_config(:command_aliases=>{"blah"=>'b'}) do
        load :blah, :file_string=>"module Blah; def blah; end; alias_method(:b, :blah); end"
        library_loaded?('blah')
        library('blah').commands.should == ['blah']
      end
    end
