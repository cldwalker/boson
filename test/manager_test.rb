require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class ManagerTest < Test::Unit::TestCase
    context "after_load" do
      def load_library(hash)
        new_attributes = {:name=>hash.delete(:name), :commands=>[], :created_dependencies=>[], :loaded=>true}
        [:module, :except, :commands].each {|e| new_attributes[e] = hash.delete(e) if hash[e] }
        Manager.expects(:load_once).returns(Library.new(new_attributes))
        Manager.load([hash[:name]])
      end

      before(:each) { reset_boson }

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
            Manager.expects(:create_instance_aliases).with({"Aquateen"=>{"frylock"=>"fr"}})
            load_library :name=>'aquateen', :commands=>['frylock'], :module=>Aquateen
            library_loaded? 'aquateen'
          end
        end

        test "created with config command_aliases" do
          with_config(:command_aliases=>{"frylock"=>"fr"}) do
            Manager.expects(:create_instance_aliases).with({"Aquateen"=>{"frylock"=>"fr"}})
            load_library :name=>'aquateen', :commands=>['frylock'], :module=>Aquateen
            library_loaded? 'aquateen'
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
        create_library('blah')
        load_library :name=>'blah'
        library_loaded? 'blah'
        Boson.libraries.size.should == 1
      end
    end

    context "option commands without args" do
      before(:all) {
        reset_boson
        @library = Library.new(:name=>'blah', :commands=>['foo', 'bar'])
        Boson.libraries << @library
        @foo = Command.new(:name=>'foo', :lib=>'blah', :options=>{:fool=>:string}, :args=>'*')
        Boson.commands << @foo
        Boson.commands << Command.new(:name=>'bar', :lib=>'blah', :options=>{:bah=>:string})
      }

      test "are deleted" do
        Scientist.expects(:create_option_command).with(anything, @foo)
        Manager.create_option_commands(@library, @library.commands)
      end

      test "are deleted and printed when verbose" do
        Scientist.expects(:create_option_command).with(anything, @foo)
        @library.instance_eval("@options = {:verbose=>true}")
        capture_stdout { Manager.create_option_commands(@library, @library.commands) } =~ /options.*blah/
      end
    end

    context "loaded" do
      before(:each) { reset_libraries }

      test "returns false when library isn't loaded" do
        create_library('blah')
        Manager.loaded?('blah').should be(false)
      end

      test "returns true when library is loaded" do
        create_library('blah', :loaded=>true)
        Manager.loaded?('blah').should be(true)
      end
    end
  end
end
