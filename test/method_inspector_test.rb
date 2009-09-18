require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class InspectorTest < Test::Unit::TestCase
    test "non commands module can't set anything" do
      eval "module Blah; end"
      MethodInspector.current_module = Blah
      Inspector.add_meta_methods
      Blah.module_eval("desc 'test'; def test; end; options :a=>1; def test2; end")
      Inspector.remove_meta_methods
      MethodInspector.store[:descriptions].empty?.should == true
      MethodInspector.store[:options].empty?.should == true
    end

    context "commands module" do
      def introspect(string)
        Inspector.add_meta_methods
        ::Boson::Commands::Zzz.module_eval(string)
        Inspector.remove_meta_methods
      end

      before(:all) { eval "module ::Boson::Commands::Zzz; end" }
      before(:each) { MethodInspector.instance_eval "@mod_store[::Boson::Commands::Zzz] = {}" }

      test "desc sets descriptions" do
        introspect "desc 'test'; def m1; end; desc 'one'; desc 'more'; def m2; end"
        MethodInspector.store[:descriptions].should == {"m1"=>"test", "m2"=>"more"}
      end

      test "options sets options" do
        introspect "options :z=>'b'; def zee; end"
        MethodInspector.store[:options].should == {"zee"=>{:z=>'b'}}
      end

      test "method_locations set if options and desc aren't set" do
        MethodInspector.stubs(:find_method_locations).returns(["/some/path", 10])
        introspect "desc 'yo'; def yo; end; options :yep=>1; def yep; end; desc 'z'; options :a=>1; def az; end"
        MethodInspector.store[:method_locations].key?('yo').should == true
        MethodInspector.store[:method_locations].key?('yep').should == true
        MethodInspector.store[:method_locations].key?('az').should == false
      end

      test "method_locations not set if find_method_locations returns nil" do
        MethodInspector.stubs(:find_method_locations).returns(nil)
        introspect "def bluh; end"
        MethodInspector.store[:method_locations].key?('bluh').should == false
      end

      test "determine_method_args called if options set" do
        ArgumentInspector.expects(:determine_method_args).returns([['arg1']])
        introspect "desc 'desc'; options :some=>:opts; def doy(arg1); end"
        MethodInspector.store[:method_args]['doy'].should == [['arg1']]
      end

      test "determine_method_args called if options in file" do
        MethodInspector.expects(:options_in_file?).returns(true)
        ArgumentInspector.expects(:determine_method_args).returns([['arg1']])
        introspect "desc 'desc'; def doz(arg1); end"
        MethodInspector.store[:method_args]['doz'].should == [['arg1']]
      end
    end
  end
end
