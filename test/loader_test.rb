require File.join(File.dirname(__FILE__), 'test_helper')
require 'boson/command_runner'

def create_runner(*methods)
  options = methods[-1].is_a?(Hash) ? methods.pop : {}
  library = options[:library] || :Blarg
  Object.send(:remove_const, library) if Object.const_defined?(library)
  Object.const_set(library, Class.new(Boson::CommandRunner)).tap do |klass|
    methods.each do |meth|
      klass.send(:define_method, meth) { }
    end
  end
end

describe "Loader" do
  describe "load" do
    before { reset }

    it "prints error for method conflicts with main_object method" do
      create_runner :require
      Inspector.disable
      capture_stderr {
        Manager.load Blarg
      }.should =~ /Unable to load library Blarg.*conflict.*commands: require/
    end

    xit "prints error for method conflicts between libraries" do
      create_runner :whoops
      create_runner :whoops, library: :Blorg
      Inspector.disable
      Manager.load Blarg
      capture_stderr {
        Manager.load Blorg
      }.should =~ /Unable to load library Blorg.*conflict.*commands: whoops/
    end
  end
end
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
  end

  after_all { FileUtils.rm_r File.dirname(__FILE__)+'/commands/', :force=>true }
end
