require File.join(File.dirname(__FILE__), 'test_helper')

describe "Manager" do
  describe ".load" do
    def load_library(hash={})
      meths = hash.delete(:commands) || []
      manager_load create_runner(*meths, library: :Blah), hash
    end

    before do
      reset_boson
      Manager.failed_libraries = []
    end

    it "loads basic library" do
      load_library
      library_loaded? 'blah'
    end

    it "loads library with commands" do
      load_library :commands=>['frylock','meatwad']
      library_loaded? 'blah'
      command_exists?('frylock')
      command_exists?('meatwad')
    end

    [SyntaxError, StandardError, LoaderError].each do |klass|
      it "prints error if library fails with #{klass}" do
        RunnerLibrary.expects(:new).raises(klass)
        load_library
        stderr.chomp.should == "Unable to load library Blah. Reason: #{klass}"
        Manager.failed_libraries.should == [Blah]
      end
    end

    [SyntaxError, StandardError].each do |klass|
      it "with verbose prints verbose error if library fails with #{klass}" do
        RunnerLibrary.expects(:new).raises(klass)
        load_library verbose: true
        stderr.should =~ /^Unable to load library Blah. Reason: #{klass}\n\s*\//
        Manager.failed_libraries.should == [Blah]
      end
    end

    it "prints error if no library is found" do
      manager_load 'dude'
      stderr.chomp.should ==
        'Unable to load library dude. Reason: Library dude not found.'
    end

    it "prints error for library that's already loaded" do
      runner = create_runner
      Manager.load runner
      manager_load runner, verbose: true
      stderr.chomp.should == "Library blarg already exists."
    end

    it "merges with existing created library" do
      create_library('blah')
      load_library
      library_loaded? 'blah'
      Boson.libraries.size.should == 1
    end
  end

  describe "option commands without args" do
    before_all {
      reset_boson
      @library = Library.new(:name=>'blah', :commands=>['foo', 'bar'])
      Boson.libraries << @library
      @foo = Command.new(:name=>'foo', :lib=>'blah', :options=>{:fool=>:string}, :args=>'*')
      Boson.commands << @foo
      Boson.commands << Command.new(:name=>'bar', :lib=>'blah', :options=>{:bah=>:string})
    }

    it "are deleted" do
      Scientist.expects(:redefine_command).with(anything, @foo)
      Manager.redefine_commands(@library, @library.commands)
    end

    it "are deleted and printed when verbose" do
      Scientist.expects(:redefine_command).with(anything, @foo)
      @library.instance_eval("@options = {:verbose=>true}")
      capture_stdout { Manager.redefine_commands(@library, @library.commands) } =~ /options.*blah/
    end
  end

  describe ".loaded?" do
    before { reset_libraries }

    it "returns false when library isn't loaded" do
      create_library('blah')
      Manager.loaded?('blah').should == false
    end
  end
end
