require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class MethodInspectorTest < Test::Unit::TestCase
    test "non commands module can't set anything" do
      eval "module Blah; end"
      MethodInspector.current_module = Blah
      Inspector.enable
      Blah.module_eval("desc 'test'; def test; end; options :a=>1; def test2; end")
      Inspector.disable
      MethodInspector.store[:desc].empty?.should == true
      MethodInspector.store[:options].empty?.should == true
    end

    context "commands module with" do
      def parse(string)
        Inspector.enable
        ::Boson::Commands::Zzz.module_eval(string)
        Inspector.disable
        MethodInspector.store
      end

      before(:all) { eval "module ::Boson::Commands::Zzz; end" }
      before(:each) { MethodInspector.mod_store.delete(::Boson::Commands::Zzz) }

      test "desc sets descriptions" do
        parsed = parse "desc 'test'; def m1; end; desc 'one'; desc 'more'; def m2; end"
        parsed[:desc].should == {"m1"=>"test", "m2"=>"more"}
      end

      test "options sets options" do
        parse("options :z=>'b'; def zee; end")[:options].should == {"zee"=>{:z=>'b'}}
      end

      test "render_options sets render_options" do
        parse("render_options :z=>true; def zee; end")[:render_options].should == {"zee"=>{:z=>true}}
      end

      test "neither options or desc set, sets method_locations" do
        MethodInspector.stubs(:find_method_locations).returns(["/some/path", 10])
        parsed = parse "desc 'yo'; def yo; end; options :yep=>1; def yep; end; render_options :a=>1; desc 'z'; options :a=>1; def az; end"
        parsed[:method_locations].key?('yo').should == true
        parsed[:method_locations].key?('yep').should == true
        parsed[:method_locations].key?('az').should == false
      end

      test "no find_method_locations doesn't set method_locations" do
        MethodInspector.stubs(:find_method_locations).returns(nil)
        parse("def bluh; end")[:method_locations].key?('bluh').should == false
      end

      test "options calls scrape_with_eval" do
        ArgumentInspector.expects(:scrape_with_eval).returns([['arg1']])
        parse("desc 'desc'; options :some=>:opts; def doy(arg1); end")[:method_args]['doy'].should == [['arg1']]
      end

      test "options in file calls scrape_with_eval" do
        MethodInspector.expects(:inspector_in_file?).returns(true)
        ArgumentInspector.expects(:scrape_with_eval).returns([['arg1']])
        parse("desc 'desc'; def doz(arg1); end")[:method_args]['doz'].should == [['arg1']]
      end
    end
  end
end
