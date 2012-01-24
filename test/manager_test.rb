require File.join(File.dirname(__FILE__), 'test_helper')

describe "Manager" do
  describe ".after_load" do
    def load_library(hash)
      new_attributes = {:name=>hash[:name], :commands=>[], :created_dependencies=>[], :loaded=>true}
      [:module, :commands].each {|e| new_attributes[e] = hash.delete(e) if hash[e] }
      Manager.expects(:rescue_load_action).returns(Library.new(new_attributes))
      Manager.load([hash[:name]])
    end

    before { reset_boson }

    it "loads basic library" do
      load_library :name=>'blah'
      library_loaded? 'blah'
    end

    it "loads library with commands" do
      load_library :name=>'blah', :commands=>['frylock','meatwad']
      library_loaded? 'blah'
      command_exists?('frylock')
      command_exists?('meatwad')
    end

    it "prints error for library with SyntaxError" do
      Manager.expects(:loader_create).raises(SyntaxError)
      capture_stderr {
        Manager.load 'blah'
      }.should =~ /Unable to load library blah. Reason: SyntaxError/
    end

    it "prints error for library with LoadError" do
      Manager.expects(:loader_create).raises(LoadError)
      capture_stderr {
        Manager.load 'blah'
      }.should =~ /Unable to load library blah. Reason: LoadError/
    end

    it "merges with existing created library" do
      create_library('blah')
      load_library :name=>'blah'
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

    it "returns true when library is loaded" do
      create_library('blah', :loaded=>true)
      Manager.loaded?('blah').should == true
    end
  end
end
