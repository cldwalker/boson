require File.join(File.dirname(__FILE__), 'test_helper')
# TODO: fix
__END__

describe "Loader" do
  before { Gem.stubs(:loaded_specs).returns({}) }
  describe "config" do
    before { reset }

    # if this test fails, other exists? using methods fail
    it "from callback recursively merges with user's config" do
      with_config(:libraries=>{'blah'=>{:commands=>{'bling'=>{:desc=>'bling', :options=>{:num=>3}}}}}) do
        File.stubs(:exists?).returns(true)
        load :blah, :file_string=> "module Blah; def self.config; {:commands=>{'blang'=>{:alias=>'ba'}, " +
          "'bling'=>{:options=>{:verbose=>:boolean}}}}; end; end"
        library('blah').command_object('bling').options.should == {:verbose=>:boolean, :num=>3}
        library('blah').command_object('bling').desc.should == 'bling'
        library('blah').command_object('blang').alias.should == 'ba'
      end
    end

    it "non-hash from inspector overridden by user's config" do
      with_config(:libraries=>{'blah'=>{:commands=>{'bling'=>{:desc=>'already'}}}}) do
        load :blah, :file_string=>"module Blah; #from file\ndef bling; end; end"
        library('blah').command_object('bling').desc.should == 'already'
      end
    end
  end

  describe "load" do
    before { reset }
    it "calls included callback" do
      capture_stdout {
        load :blah, :file_string=>"module Blah; def self.included(mod); puts 'included blah'; end; def blah; end; end"
      }.should =~ /included blah/
    end

    it "calls after_included callback" do
      capture_stdout {
        load :blah, :file_string=>"module Blah; def self.after_included; puts 'yo'; end; end"
      }.should == "yo\n"
    end

    it "prints error if library module conflicts with top level constant/module" do
      capture_stderr {
        load :blah, :file_string=>"module Object; def self.blah; end; end"
      }.should =~ /conflict.*'Object'/
      library_loaded?('blah')
    end

    it "prints error and returns false for existing library" do
      libs = create_library('blah', :loaded=>true)
      Manager.stubs(:loader_create).returns(libs[0])
      capture_stderr { load('blah', :no_mock=>true, :verbose=>true).should == false }.should =~ /already exists/
    end

    it "loads and strips aliases from a library's commands" do
      with_config(:command_aliases=>{"blah"=>'b'}) do
        load :blah, :file_string=>"module Blah; def blah; end; alias_method(:b, :blah); end"
        library_loaded?('blah')
        library('blah').commands.should == ['blah']
      end
    end

    it "prints error for method conflicts with main_object method" do
      with_config(:error_method_conflicts=>true) do
        capture_stderr {
          load('blah', :file_string=>"module Blah; def require; end; end")
        }.should =~ /Unable to load library blah.*conflict.*require/
      end
    end

    it "prints error for method conflicts with config error_method_conflicts" do
      with_config(:error_method_conflicts=>true) do
        load('blah', :file_string=>"module Blah; def chwhat; end; end")
        capture_stderr {
          load('chwhat', :file_string=>"module Chwhat; def chwhat; end; end")
        }.should =~ /Unable to load library chwhat.*conflict.*chwhat/
      end
    end
  end

  after_all { FileUtils.rm_r File.dirname(__FILE__)+'/commands/', :force=>true }
end
