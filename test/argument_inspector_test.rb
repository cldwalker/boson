require File.join(File.dirname(__FILE__), 'test_helper')

describe "scrape_with_text" do
  def args_from(file_string)
    ArgumentInspector.scrape_with_text(file_string, "blah")
  end

  test "parses arguments of class method" do
    args_from("    def YAML.blah( filepath )\n").should == [['filepath']]
  end

  test "parses arguments with no spacing" do
    args_from("def bong; end\ndef blah(arg1,arg2='val2')\nend").should == [["arg1"], ['arg2', "'val2'"]]
  end

  test "parses arguments with spacing" do
    args_from("\t def blah(  arg1=val1, arg2 = val2)").should == [["arg1","val1"], ["arg2", "val2"]]
  end

  test "parses arguments without parenthesis" do
    args_from(" def blah arg1, arg2, arg3={}").should == [['arg1'], ['arg2'], ['arg3','{}']]
  end
end

describe "scrape_with_eval" do
  def args_from(string)
    # methods need options to have their args parsed with ArgumentInspector
    string.gsub!(/(def blah)/, 'options :a=>1; \1')
    Inspector.enable
    ::Boson::Commands::Aaa.module_eval(string)
    Inspector.disable
    MethodInspector.store[:args]['blah']
  end

  before_all { eval "module ::Boson::Commands::Aaa; end"; }
  before { MethodInspector.mod_store[::Boson::Commands::Aaa] = {} }

  test "determines arguments with literal defaults" do
    args_from("def blah(arg1,arg2='val2'); end").should == [['arg1'], ['arg2','val2']]
  end

  test "determines splat arguments" do
    args_from("def blah(arg1, *args); end").should == [['arg1'], ["*args"]]
  end

  test "determines arguments with local values before a method" do
    body = "AWESOME='awesome'; def sweet; 'ok'; end; def blah(arg1=AWESOME, arg2=sweet); end"
    args_from(body).should == [['arg1', 'awesome'], ['arg2', 'ok']]
  end

  test "doesn't get arguments with local values after a method" do
    args_from("def blah(arg1=nope) end; def nope; 'nope'; end").should == nil
  end

  test "doesn't determine arguments of a private method" do
    args_from("private; def blah(arg1,arg2); end").should == nil
  end

  test "doesn't determine arguments if an error occurs" do
    args_from("def blah(arg1,arg2=raise); end").should == nil
  end
end