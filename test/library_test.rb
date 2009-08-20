require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LibraryTest < Test::Unit::TestCase    
    context "load" do
      def load_library(hash)
        lib = Library.loader_create Library.default_attributes.merge(hash).merge(:created_dependencies=>[])
        Library.expects(:load_once).returns(lib)
        Library.load([hash[:name]])
      end

      before(:each) { reset_libraries; reset_commands}

      test "loads basic library" do
        load_library :name=>'blah'
        Library.loaded?('blah').should == true
      end

      test "loads library with commands" do
        load_library :name=>'blah', :commands=>['frylock','meatwad']
        Library.loaded?('blah').should == true
        command_exists?('frylock').should == true
        command_exists?('meatwad').should == true
      end

      test "loads library with commands and except option" do
        Boson.main_object.instance_eval("class<<self;self;end").expects(:undef_method).with('frylock')
        load_library :name=>'blah', :commands=>['frylock','meatwad'], :except=>['frylock']
        Library.loaded?('blah').should == true
        command_exists?('frylock').should == false
        command_exists?('meatwad').should == true
      end

      test "creates aliases for commands" do
        eval %[module ::Aquateen; def frylock; end; end]
        with_config(:commands=>{'frylock'=>{:alias=>'fr'}}) do
          load_library :name=>'aquateen', :commands=>['frylock','meatwad'], :module=>Aquateen
          Library.loaded?('aquateen').should == true
          Aquateen.method_defined?(:fr).should == true
        end
      end

      test "doesn't create aliases and warns for commands with no module" do
        eval %[module ::Aquateen2; def frylock; end; end]
        with_config(:commands=>{'frylock'=>{:alias=>'fr'}}) do
          capture_stderr { 
            load_library(:name=>'aquateen', :commands=>['frylock','meatwad'])
          }.should =~ /No aliases/
          Library.loaded?('aquateen').should == true
          Aquateen2.method_defined?(:fr).should == false
        end
      end

      test "merges with existing created library" do
        Library.create(['blah'])
        load_library :name=>'blah'
        Library.loaded?('blah').should == true
        Boson.libraries.size.should == 1
      end
    end

    context "create" do
      before(:each) { reset_libraries }
      test "creates library" do
        Library.create(['blah'])
        Boson.libraries.find_by(:name=>'blah').is_a?(Library).should be(true)
      end

      test "creates library with config" do
        with_config(:libraries => {'blah'=>{:dependencies=>['bluh']}}) do
          Library.create(['blah'])
          Boson.libraries.find_by(:name=>'blah').is_a?(Library).should be(true)
          Boson.libraries.find_by(:name=>'blah').dependencies.should == ['bluh']
        end
      end

      # td: merge created libraries?
      test "merges multiple libraries with same name into one" do
        Library.create(['doh'])
        Library.create(['doh'])
        Boson.libraries.size.should == 1
      end
    end

    context "loaded" do
      before(:each) { reset_libraries }

      test "returns false when library isn't loaded" do
        Library.create(['blah'])
        Library.loaded?('blah').should be(false)
      end

      test "returns true when library is loaded" do
        Library.create(['blah'], :loaded=>true)
        Library.loaded?('blah').should be(true)
      end
    end
  end
end
