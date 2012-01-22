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

    it "loads a library and creates its class commands" do
      with_config(:libraries=>{"blah"=>{:class_commands=>{"bling"=>"Blah.bling", "Blah"=>['hmm']}}}) do
        load :blah, :file_string=>"module Blah; def self.bling; end; def self.hmm; end; end"
        command_exists? 'bling'
        command_exists? 'hmm'
      end
    end

    it "loads a library with dependencies" do
      File.stubs(:exists?).returns(true)
      File.stubs(:read).returns("module Water; def water; end; end", "module Oaks; def oaks; end; end")
      with_config(:libraries=>{"water"=>{:dependencies=>"oaks"}}) do
        load 'water', :no_mock=>true
        library_has_module('water', "Boson::Commands::Water")
        library_has_module('oaks', "Boson::Commands::Oaks")
        command_exists?('water')
        command_exists?('oaks')
      end
    end

    it "prints error for library with invalid dependencies" do
      GemLibrary.stubs(:is_a_gem?).returns(true) #mock all as gem libs
      Util.stubs(:safe_require).returns(true)
      with_config(:libraries=>{"water"=>{:dependencies=>"fire"}, "fire"=>{:dependencies=>"man"}}) do
        capture_stderr {
          load('water', :no_mock=>true)
        }.should == "Unable to load library fire. Reason: Can't load dependency man\nUnable to load"+
        " library water. Reason: Can't load dependency fire\n"
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

    describe "module library" do
      def mock_library(*args); end

      it "loads a module library and all its class methods by default" do
        eval %[module ::Harvey; def self.bird; end; def self.eagle; end; end]
        load ::Harvey, :no_mock=>true
        library_has_command('harvey', 'bird')
        library_has_command('harvey', 'eagle')
      end

      it "loads a module library with specified commands" do
        eval %[module ::Peanut; def self.bird; end; def self.eagle; end; end]
        load ::Peanut, :no_mock=>true, :commands=>%w{bird}
        library('peanut').commands.size.should == 1
        library_has_command('peanut', 'bird')
      end

      it "loads a module library as a class" do
        eval %[class ::Mentok; def self.bird; end; def self.eagle; end; end]
        load ::Mentok, :no_mock=>true, :commands=>%w{bird}
        library('mentok').commands.size.should == 1
        library_has_command('mentok', 'bird')
      end
    end

    describe "gem library" do
      def mock_library(lib, options={})
        options[:file_string] ||= ''
        File.stubs(:exists?).returns(false)
        GemLibrary.expects(:is_a_gem?).returns(true)
        Util.expects(:safe_require).with { eval options.delete(:file_string) || ''; true}.returns(true)
      end

      it "loads" do
        with_config(:libraries=>{"dude"=>{:module=>'Dude'}}) do
          load "dude", :file_string=>"module ::Dude; def blah; end; end"
          library_has_module('dude', "Dude")
          command_exists?("blah")
        end
      end

      it "with kernel methods loads" do
        load "dude", :file_string=>"module ::Kernel; def dude; end; end"
        library_loaded? 'dude'
        library('dude').module.should == nil
        command_exists?("dude")
      end

      it "prints error when nonexistent" do
        capture_stderr { load('blah') }.should =~ /Library blah did not/
      end

      it "with invalid module prints error" do
        with_config(:libraries=>{"coolio"=>{:module=>"Cool"}}) do
          capture_stderr {
            load('coolio', :file_string=>"module ::Coolio; def coolio; end; end")
          }.should =~ /Unable.*coolio.*No module/
        end
      end
    end
  end

  after_all { FileUtils.rm_r File.dirname(__FILE__)+'/commands/', :force=>true }
end
