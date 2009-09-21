require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class ArgumentInspectorTest < Test::Unit::TestCase
    context "arguments_from_file" do
      def args_from(file_string)
        ArgumentInspector.arguments_from_file(file_string, "blah")
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

    context "determine_method_args" do
      def args_from(string)
        # methods need options to have their args parsed with ArgumentInspector
        string.gsub!(/(def blah)/, 'options :a=>1; \1')
        Inspector.add_meta_methods
        ::Boson::Commands::Aaa.module_eval(string)
        Inspector.remove_meta_methods
        MethodInspector.store[:method_args]['blah']
      end

      before(:all) { eval "module ::Boson::Commands::Aaa; end"; }
      before(:each) { MethodInspector.mod_store[::Boson::Commands::Aaa] = {} }

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
  end
end