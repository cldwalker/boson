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

    it "loads basic library with verbose" do
      capture_stdout {
          load_library verbose: true
      }.chomp.should == 'Loaded library blah'
      library_loaded? 'blah'
    end

    it "loads library with commands" do
      load_library :commands=>['frylock','meatwad']
      library_loaded? 'blah'
      library_has_command 'blah', 'frylock'
      library_has_command 'blah', 'meatwad'
    end

    it "prints error if library does not load" do
      RunnerLibrary.any_instance.expects(:load).returns false
      load_library
      stderr.should == "Library blah did not load successfully."
    end

    [SyntaxError, StandardError, LoaderError].each do |klass|
      it "prints error if library fails with #{klass}" do
        RunnerLibrary.expects(:new).raises(klass)
        load_library
        stderr.should == "Unable to load library Blah. Reason: #{klass}"
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
      stderr.should ==
        'Unable to load library dude. Reason: Library dude not found.'
    end

    it "prints error for library that's already loaded" do
      runner = create_runner
      Manager.load runner
      manager_load runner, verbose: true
      stderr.should == "Library blarg already exists."
    end

    it "merges with existing created library" do
      create_library(name: 'blah')
      load_library
      library_loaded? 'blah'
      Boson.libraries.size.should == 1
    end
  end

  describe ".redefine_commands" do
    before do
      reset_boson
      @library = create_library(:name=>'blah', :commands=>['foo', 'bar'])
      @foo = create_command(name: 'foo', lib: 'blah', options: {fool: :string},
        args: '*')
      create_command(name: 'bar', lib: 'blah', options: {bah: :string})
    end

    it "only redefines commands with args" do
      Scientist.expects(:redefine_command).with(anything, @foo)
      Manager.redefine_commands(@library, @library.commands)
    end

    it "with verbose only redefines commands with args and prints rejected" do
      Manager.verbose = true
      Scientist.expects(:redefine_command).with(anything, @foo)
      capture_stdout {
        Manager.redefine_commands(@library, @library.commands)
      }.should =~ /cannot have options.*bar/
      Manager.verbose = nil
    end
  end

  describe ".loaded?" do
    before { reset_libraries }

    it "returns false when library isn't loaded" do
      create_library(name: 'blah')
      Manager.loaded?('blah').should == false
    end
  end
end
