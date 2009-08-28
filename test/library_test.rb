require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LibraryTest < Test::Unit::TestCase    
    context "after_load" do
      def load_library(hash)
        new_attributes = {:name=>hash.delete(:name), :commands=>[], :created_dependencies=>[], :loaded=>true}
        [:module, :except, :commands].each {|e| new_attributes[e] = hash.delete(e) if hash[e] }
        Library.expects(:load_once).returns(Library.new(new_attributes))
        Library.load([hash[:name]])
      end

      before(:each) { reset_libraries; reset_commands}

      test "loads basic library" do
        load_library :name=>'blah'
        library_loaded? 'blah'
      end

      test "loads library with commands" do
        load_library :name=>'blah', :commands=>['frylock','meatwad']
        library_loaded? 'blah'
        command_exists?('frylock')
        command_exists?('meatwad')
      end

      test "loads library with commands and except option" do
        Boson.main_object.instance_eval("class<<self;self;end").expects(:undef_method).with('frylock')
        load_library :name=>'blah', :commands=>['frylock','meatwad'], :except=>['frylock']
        library_loaded? 'blah'
        command_exists?('frylock', false)
        command_exists?('meatwad')
      end

      context "command aliases" do
        before(:each) { eval %[module ::Aquateen; def frylock; end; end] }
        after(:each) { Object.send(:remove_const, "Aquateen") }

        test "created with command specific config" do
          with_config(:commands=>{'frylock'=>{:alias=>'fr'}}) do
            load_library :name=>'aquateen', :commands=>['frylock'], :module=>Aquateen
            library_loaded? 'aquateen'
            Aquateen.method_defined?(:fr).should == true
          end
        end

        test "created with config command_aliases" do
          with_config(:command_aliases=>{"frylock"=>"fr"}) do
            load_library :name=>'aquateen', :commands=>['frylock'], :module=>Aquateen
            library_loaded? 'aquateen'
            Aquateen.method_defined?(:fr).should == true
          end
        end

        test "not created and warns for commands with no module" do
          with_config(:commands=>{'frylock'=>{:alias=>'fr'}}) do
            capture_stderr {
              load_library(:name=>'aquateen', :commands=>['frylock'])
            }.should =~ /No aliases/
            library_loaded? 'aquateen'
            Aquateen.method_defined?(:fr).should == false
          end
        end
      end

      test "merges with existing created library" do
        Library.create(['blah'])
        load_library :name=>'blah'
        library_loaded? 'blah'
        Boson.libraries.size.should == 1
      end
    end

    context "create" do
      before(:each) { reset_libraries }
      test "creates library" do
        Library.create(['blah'])
        library('blah').is_a?(Library).should == true
      end

      test "creates library with config" do
        with_config(:libraries => {'blah'=>{:dependencies=>['bluh']}}) do
          Library.create(['blah'])
          library('blah').is_a?(Library).should be(true)
          library('blah').dependencies.should == ['bluh']
        end
      end

      test "only makes one library with the same name" do
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
