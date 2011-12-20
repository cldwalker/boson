require File.join(File.dirname(__FILE__), 'test_helper')
require 'boson/bin_runner'
BinRunner = Boson::BinRunner

describe "BinRunner" do
  unless ENV['FAST']
    it "prints usage with no arguments" do
      boson
      stdout.should =~ /^boson/
    end

    it "prints usage with --help" do
      %w{-h --help}.each do |option|
        boson option
        stdout.should =~ /^boson/
      end
    end

    it 'prints version with --version' do
      boson '--version'
      stdout.chomp.should == "boson #{Boson::VERSION}"
    end

    it "executes string with --execute" do
      %w{--execute -e}.each do |option|
        boson "#{option} 'print 1 + 1'"
        stdout.should == '2'
      end
    end

    it "sets $DEBUG with --ruby-debug" do
      %w{--ruby_debug -D}.each do |option|
        boson "#{option} -e 'print $DEBUG'"
        stdout.should == 'true'
      end
    end

    # TODO: test actual uses of Runner.debug
    it "sets Runner.debug with --debug" do
      boson "--debug -e 'print Boson::Runner.debug'"
      stdout.should == 'true'
    end

    it "prepends to $: with --load_path" do
      %w{--load_path -I}.each do |option|
        boson "#{option}=lib -e 'print $:[0]'"
        stdout.should == 'lib'
      end
    end

    it "prints error for unexpected error" do
      boson %[-e 'raise "blarg"']
      stderr.chomp.should == "Error: blarg"
      process.success?.should == false
    end

    it "prints error for too many arguments" do
      boson "commands 1 2 3"
      stderr.should =~ /^'commands' was called incorrectly/
      process.success?.should == false
    end

    it "prints error for invalid command" do
      boson 'blarg'
      stderr.chomp.should == "Error: Command 'blarg' not found"
      process.success?.should == false
    end
  end

  # TODO: moar acceptance tests
  xit "basic command executes" do
    BinRunner.expects(:init).returns(true)
    BinRunner.stubs(:render_output)
    Boson.main_object.expects(:send).with('kick','it')
    start 'kick','it'
  end
  xit "bin_defaults config loads by default"

  def start(*args)
    BinRunner.start(args)
  end

  before {|e|
    BinRunner.instance_variables.each {|e| BinRunner.instance_variable_set(e, nil)}
  }

  # TODO: fix missing libraries command
  xdescribe "autoload_command" do
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

  it "parse_args only translates options before command" do
    BinRunner.parse_args(['-d', 'com', '-v']).should == ["com", {debug: true}, ['-v']]
    BinRunner.parse_args(['com', '-v']).should == ["com", {}, ['-v']]
  end
end

__END__
describe "BinRunner" do
  describe "at commandline" do
    before_all { reset }

    it "failed subcommand prints error and not command not found" do
      BinRunner.expects(:execute_command).raises("bling")
      aborts_with(/Error: bling/) { start("commands.to_s") }
    end

    it "nonexistant subcommand prints command not found" do
      aborts_with(/'to_s.bling' not found/) { start("to_s.bling") }
    end

    it "sub command executes" do
      obj = Object.new
      Boson.main_object.extend Module.new { def phone; Struct.new(:home).new('done'); end }
      BinRunner.expects(:init).returns(true)
      start 'phone.home'
    end
  end
end
