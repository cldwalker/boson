require File.join(File.dirname(__FILE__), 'test_helper')
require 'boson/runners/bin_runner'
BinRunner = Boson::BinRunner

describe "BinRunner" do
  def start(*args)
    Hirb.stubs(:enable)
    BinRunner.start(args)
  end

  before {|e|
    BinRunner.instance_variables.each {|e| BinRunner.instance_variable_set(e, nil)}
  }
  describe "at commandline" do
    before_all { reset }

    it "no arguments prints usage" do
      capture_stdout { start }.should =~ /^boson/
    end

    it "invalid option value prints error" do
      aborts_with(/Error: no value/) { start("-l") }
    end

    it "help option but no arguments prints usage" do
      capture_stdout { start '-h' }.should =~ /^boson/
    end

    it "help option and command prints help" do
      capture_stdout { start('-h', 'commands') }.should =~ /^commands/
    end

    it "load option loads libraries" do
      Manager.expects(:load).with {|*args| args[0][0].is_a?(Module) ? true : args[0][0] == 'blah'}.times(2)
      BinRunner.stubs(:execute_command)
      start('-l', 'blah', 'libraries')
    end

    # it "console option starts irb" do
    #   ConsoleRunner.expects(:start)
    #   Util.expects(:which).returns("/usr/bin/irb")
    #   Kernel.expects(:load).with("/usr/bin/irb")
    #   start("--console")
    # end

    it "console option but no irb found prints error" do
      ConsoleRunner.expects(:start)
      Util.expects(:which).returns(nil)
      capture_stderr { start("--console") }.should =~ /Console not found/
    end

    it "execute option executes string" do
      BinRunner.expects(:define_autoloader)
      capture_stdout { start("-e", "p 1 + 1") }.should == "2\n"
    end

    it "global option takes value with whitespace" do
      View.expects(:render).with {|*args| args[1][:fields] = %w{f1 f2} }
      start('commands', '-f', 'f1, f2')
    end

    it "execute option errors are caught" do
      aborts_with(/^Error:/) { start("-e", "raise 'blah'") }
    end

    it "option command and too many arguments prints error" do
      capture_stdout {
        capture_stderr { start('commands','1','2','3') }.should =~ /'commands'.*incorrect/
      }
    end

    it "normal command and too many arguments prints error" do
      capture_stdout {
        capture_stderr { start('render') }.should =~ /'render'.*incorrect/
      }
    end

    it "failed subcommand prints error and not command not found" do
      BinRunner.expects(:execute_command).raises("bling")
      aborts_with(/Error: bling/) { start("commands.to_s") }
    end

    it "nonexistant subcommand prints command not found" do
      aborts_with(/'to_s.bling' not found/) { start("to_s.bling") }
    end

    it "undiscovered command prints error" do
      BinRunner.expects(:autoload_command).returns(false)
      aborts_with(/Error.*not found/) { start 'blah' }
    end

    it "basic command executes" do
      BinRunner.expects(:init).returns(true)
      BinRunner.stubs(:render_output)
      Boson.main_object.expects(:send).with('kick','it')
      start 'kick','it'
    end

    it "sub command executes" do
      obj = Object.new
      Boson.main_object.extend Module.new { def phone; Struct.new(:home).new('done'); end }
      BinRunner.expects(:init).returns(true)
      BinRunner.expects(:render_output).with('done')
      start 'phone.home'
    end

    it "bin_defaults config loads by default" do
      defaults = Runner.default_libraries + ['yo']
      with_config(:bin_defaults=>['yo']) do
        Manager.expects(:load).with {|*args| args[0] == defaults }
        aborts_with(/blah/) { start 'blah' }
      end
    end
  end

  describe "autoload_command" do
    def index(options={})
      Manager.expects(:load).with {|*args| args[0][0].is_a?(Module) ? true : args[0] == options[:load]
        }.at_least(1).returns(!options[:fails])
      Index.indexes[0].expects(:write)
    end

    it "with index option, no existing index and core command updates index and prints index message" do
      index :load=>Runner.all_libraries
      Index.indexes[0].stubs(:exists?).returns(false)
      capture_stdout { start("--index", "libraries") }.should =~ /Generating index/
    end

    it "with index option, existing index and core command updates incremental index" do
      index :load=>['changed']
      Index.indexes[0].stubs(:exists?).returns(true)
      capture_stdout { start("--index=changed", "libraries")}.should =~ /Indexing.*changed/
    end

    it "with index option, failed indexing prints error" do
      index :load=>['changed'], :fails=>true
      Index.indexes[0].stubs(:exists?).returns(true)
      Manager.stubs(:failed_libraries).returns(['changed'])
      capture_stderr {
        capture_stdout { start("--index=changed", "libraries")}.should =~ /Indexing.*changed/
      }.should =~ /Error:.*failed.*changed/
    end

    it "with core command updates index and doesn't print index message" do
      Index.indexes[0].expects(:write)
      Boson.main_object.expects(:send).with('libraries')
      capture_stdout { start 'libraries'}.should.not =~ /index/i
    end

    it "with non-core command not finding library, does update index" do
      Index.expects(:find_library).returns(nil, 'sweet_lib')
      Manager.expects(:load).with {|*args| args[0].is_a?(String) ? args[0] == 'sweet_lib' : true}.at_least(1)
      Index.indexes[0].expects(:update).returns(true)
      aborts_with(/sweet/) { start 'sweet' }
    end
  end

  describe "render_output" do
    before { Scientist.rendered = false; BinRunner.instance_eval "@options = {}" }

    it "doesn't render when nil, false or true" do
      View.expects(:render).never
      [nil, false, true].each do |e|
        BinRunner.render_output e
      end
    end

    it "doesn't render when rendered with Scientist" do
      Scientist.rendered = true
      View.expects(:render).never
      BinRunner.render_output 'blah'
    end

    it "render with puts when non-string" do
      View.expects(:render).with('dude', {:method => 'puts'})
      BinRunner.render_output 'dude'
    end

    it "renders with inspect when non-array and non-string" do
      [{:a=>true}, :ok].each do |e|
        View.expects(:puts).with(e.inspect)
        BinRunner.render_output e
      end
    end

    it "renders with inspect when Scientist rendering toggled off with :render" do
      Scientist.global_options = {:render=>true}
      View.expects(:puts).with([1,2].inspect)
      BinRunner.render_output [1,2]
      Scientist.global_options = nil
    end

    it "renders with hirb when array" do
      View.expects(:render_object)
      BinRunner.render_output [1,2,3]
    end
  end

  it "parse_args only translates options before command" do
    BinRunner.parse_args(['-v', 'com', '-v']).should == ["com", {:verbose=>true}, ['-v']]
    BinRunner.parse_args(['com', '-v']).should == ["com", {}, ['-v']]
  end
end