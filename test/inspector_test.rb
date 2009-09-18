require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class InspectorTest < Test::Unit::TestCase
    def introspect(string)
      Inspector.add_meta_methods
      Blah.module_eval(string)
      Inspector.remove_meta_methods
    end

    before(:all) { eval "module Blah; end" }
    before(:each) { Blah.instance_eval "@_method_locations = nil" }
    test "desc sets descriptions" do
      introspect "desc 'test'; def m1; end; desc 'one'; desc 'more'; def m2; end"
      Inspector.get_attribute(Blah, :descriptions).should == {"m1"=>"test", "m2"=>"more"}
      Inspector.attribute?(Blah, :descriptions).should == true
    end

    test "options sets options" do
      introspect "options :z=>'b'; def zee; end"
      Inspector.get_attribute(Blah, :options).should == {"zee"=>{:z=>'b'}}
      Inspector.attribute?(Blah, :options).should == true
    end
  end
end