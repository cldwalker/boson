require File.join(File.dirname(__FILE__), 'test_helper')

describe "MethodInspector" do
  before_all { MethodInspector.mod_store = {} }

  it "non commands module can't set anything" do
    eval "module Blah; end"
    MethodInspector.current_module = Blah
    Inspector.enable
    Blah.module_eval("desc 'test'; def test; end; options :a=>1; def test2; end")
    Inspector.disable
    MethodInspector.store[:desc].empty?.should == true
    MethodInspector.store[:options].empty?.should == true
  end

  it "handles anonymous classes" do
    MethodInspector.mod_store = {}
    Inspector.enable
    Class.new.module_eval "def blah; end"
    Inspector.disable
    MethodInspector.store.should == nil
  end

  describe "commands module with" do
    def parse(string)
      Inspector.enable
      ::Boson::Commands::Zzz.module_eval(string)
      Inspector.disable
      MethodInspector.store
    end

    before_all { eval "module ::Boson::Commands::Zzz; end" }
    before { MethodInspector.mod_store.delete(::Boson::Commands::Zzz) }

    it "desc sets descriptions" do
      parsed = parse "desc 'test'; def m1; end; desc 'one'; desc 'more'; def m2; end"
      parsed[:desc].should == {"m1"=>"test", "m2"=>"more"}
    end

    it "options sets options" do
      parse("options :z=>'b'; def zee; end")[:options].should == {"zee"=>{:z=>'b'}}
    end

    it "option sets options" do
      parse("option :z, 'b'; option :y, :boolean; def zee; end")[:options].should ==
        {"zee"=>{:z=>'b', :y=>:boolean}}
    end

    it "option(s) sets options" do
      parse("options :z=>'b'; option :y, :string; def zee; end")[:options].should ==
        {"zee"=>{:z=>'b', :y=>:string}}
    end

    it "option(s) option overrides options" do
      parse("options :z=>'b'; option :z, :string; def zee; end")[:options].should ==
        {"zee"=>{:z=>:string}}
    end

    it "config sets config" do
      parse("config :z=>true; def zee; end")[:config].should == {"zee"=>{:z=>true}}
    end

    it "not all method attributes set causes method_locations to be set" do
      MethodInspector.stubs(:find_method_locations).returns(["/some/path", 10])
      parsed = parse "desc 'yo'; def yo; end; options :yep=>1; def yep; end; " +
        "option :b, :boolean; config :a=>1; desc 'z'; options :a=>1; def az; end"
      parsed[:method_locations].key?('yo').should == true
      parsed[:method_locations].key?('yep').should == true
      parsed[:method_locations].key?('az').should == false
    end

    it "no find_method_locations doesn't set method_locations" do
      MethodInspector.stubs(:find_method_locations).returns(nil)
      parse("def bluh; end")[:method_locations].key?('bluh').should == false
    end
  end

  describe "scrape_arguments" do
    def args_from(file_string)
      MethodInspector.scrape_arguments(file_string, "blah")
    end

    it "parses arguments of class method" do
      args_from("    def YAML.blah( filepath )\n").should == [['filepath']]
    end

    it "parses arguments with no spacing" do
      args_from("def bong; end\ndef blah(arg1,arg2='val2')\nend").should == [["arg1"], ['arg2', "'val2'"]]
    end

    it "parses arguments with spacing" do
      args_from("\t def blah(  arg1=val1, arg2 = val2)").should == [["arg1","val1"], ["arg2", "val2"]]
    end

    it "parses arguments without parenthesis" do
      args_from(" def blah arg1, arg2, arg3={}").should == [['arg1'], ['arg2'], ['arg3','{}']]
    end
  end

end
