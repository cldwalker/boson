require File.dirname(__FILE__) + '/test_helper'
require 'shellwords'

# hack required to re-add default_commands_runner methods
$".delete_if {|e| e[%r{boson/runner.rb$}] }
Boson.send(:remove_const, :Runner)
Boson.send(:remove_const, :DefaultCommandsRunner)
require 'boson/runner'

# remove side effects from other tests
Boson::Runner::GLOBAL_OPTIONS.delete_if {|k,v| k != :help }

class MyRunner < Boson::Runner
  desc "This is a small"
  def small(*args)
    p args
  end

  option :tags, :type => :array
  option :blurg, :type => :boolean, :required => true
  desc 'This is splot'
  def splot(*args)
    p args
  end

  option :spicy, type: :boolean, desc: 'hot'
  desc "This is a medium"
  def medium(arg=nil, opts={})
    p [arg, opts]
  end

  desc "This is a mini"
  def mini(me)
  end

  def quiet
  end

  def explode(arg=nil)
    {}.update
  end

  def boom
    nil.boom
  end

  def broken
    raise ArgumentError
  end

  def test
    puts "TEST"
  end

  private
  def no_run
  end
end

class ExtendedRunner < Boson::Runner
  def self.execute(command, args, options)
    options[:version] ? puts("Version 1000.0") : super
  end

  def self.display_command_help(cmd)
    super
    puts "And don't forget to eat BAACCCONN"
  end
end

describe "Runner" do
  before_all { reset }

  def my_command(cmd='')
    $0 = 'my_command'
    capture_stdout do
      MyRunner.start Shellwords.split(cmd)
    end
  end

  def extended_command(cmd='')
    $0 = 'extended_command'
    capture_stdout do
      ExtendedRunner.start Shellwords.split(cmd)
    end
  end

  def default_usage
    <<-STR
Usage: my_command [OPTIONS] COMMAND [ARGS]

Available commands:
  boom
  broken
  explode
  help     Displays help for a command
  medium   This is a medium
  mini     This is a mini
  quiet
  small    This is a small
  splot    This is splot
  test

Options:
  -h, --help  Displays this help message
STR
  end

  it "prints sorted commands by default" do
    my_command.should == default_usage
  end

  it "prints default usage for -h and --help" do
    my_command('-h').should == default_usage
    my_command('--help').should == default_usage
  end

  describe "for help COMMAND" do
    it 'prints help for valid command' do
      my_command('help quiet').should ==<<-STR
Usage: my_command quiet

Description:
  TODO
STR
    end

    it 'prints error for invalid command' do
      Boson::DefaultCommandsRunner.expects(:abort).
        with("my_command: Could not find command \"invalid\"")
      my_command('help invalid')
    end

    it 'prints general help if no command' do
      my_command('help').should == default_usage
    end
  end

  describe "for COMMAND -h" do
    it "prints help for descriptionless command" do
      my_command('quiet -h').should == <<-STR
Usage: my_command quiet

Description:
  TODO
STR
    end

    it "prints help for optionless command with splat args" do
      my_command('small -h').should == <<-STR
Usage: my_command small *ARGS

Description:
  This is a small
STR
    end

    it "prints help for optionless command with required args" do
      my_command('mini -h').should == <<-STR
Usage: my_command mini ME

Description:
  This is a mini
STR
    end

    it "prints help for command with options and optional args" do
      my_command('medium -h').should == <<-STR
Usage: my_command medium [ARG]

Options:
  -s, --spicy  hot

Description:
  This is a medium
STR
    end
  end

  it "handles command with default arguments correctly" do
    my_command('medium').chomp.should == '[nil, {}]'
  end

  it "calls command with options correctly" do
    my_command('medium 1 --spicy').chomp.should == '["1", {:spicy=>true}]'
  end

  it "calls command with additional invalid option" do
    capture_stderr {
      my_command('medium 1 -z').chomp.should == '["1", {}]'
    }.should == "Deleted invalid option '-z'\n"
  end

  it "calls command with quoted arguments correctly" do
    my_command("medium '1 2'").chomp.should == '["1 2", {}]'
  end

  it "calls optionless command correctly" do
    my_command('small 1 2').chomp.should == '["1", "2"]'
  end

  it "calls command with too many args" do
    MyRunner.expects(:abort).with <<-STR.chomp
my_command: 'medium' was called incorrectly.
Usage: medium [ARG]
STR
    my_command('medium 1 2 3')
  end

  it "calls command with splat args and multiple options correctly" do
    Boson.in_shell = true
    my_command('splot 1 2 -b --tags=1,2').chomp.should ==
      '["1", "2", {:blurg=>true, :tags=>["1", "2"]}]'
    Boson.in_shell = nil
  end

  it "prints error for command with option parse error" do
    MyRunner.expects(:abort).with <<-STR.chomp
my_command: no value provided for required option 'blurg'
STR
    my_command('splot 1')
  end

  it "executes custom global option" do
    # setup goes here to avoid coupling to other runner
    ExtendedRunner::GLOBAL_OPTIONS[:version] = {
      type: :boolean, :desc => 'Print version'
    }

    extended_command('-v').chomp.should == 'Version 1000.0'
  end

  it "allows Kernel-method command names" do
    my_command('test').chomp.should == 'TEST'
  end

  it "prints error message for internal public method" do
    MyRunner.expects(:abort).with %[my_command: Could not find command "to_s"]
    my_command('to_s').should == ''
  end

  it "prints error message for nonexistant command" do
    MyRunner.expects(:abort).with %[my_command: Could not find command "blarg"]
    my_command('blarg').should == ''
  end

  it 'prints error message for command missing required args' do
    MyRunner.expects(:abort).with <<-STR.chomp
my_command: 'mini' was called incorrectly.
Usage: mini ME
STR
    my_command('mini').should == ''
  end
  it "allows no method error in command" do
    assert_error(NoMethodError) { my_command('boom') }
  end

  it "allows argument error in command" do
    assert_error(ArgumentError) { my_command('broken') }
  end

  it "allows argument error in command with optional args" do
    assert_error(ArgumentError) { my_command('explode') }
  end

  it "prints error message for private method" do
    MyRunner.expects(:abort).with %[my_command: Could not find command "no_run"]
    my_command('no_run').should == ''
  end

  describe "$BOSONRC" do
    before { ENV.delete('BOSONRC') }

    it "is not loaded by default" do
      MyRunner.expects(:load).never
      my_command('quiet').should == ''
    end

    it "is loaded if set" do
      ENV['BOSONRC'] = 'whoop'
      File.expects(:exists?).returns(true)
      MyRunner.expects(:load).with('whoop')
      my_command('quiet')
    end

    after_all { ENV['BOSONRC'] = File.dirname(__FILE__) + '/.bosonrc' }
  end

  describe "extend Runner" do
    it "can extend help" do
      extended_command('help help').should == <<-STR
Usage: extended_command help [CMD]

Description:
  Displays help for a command
And don't forget to eat BAACCCONN
STR
    end

    it "can extend a command's --help" do
      extended_command('help -h').should == <<-STR
Usage: extended_command help [CMD]

Description:
  Displays help for a command
And don't forget to eat BAACCCONN
STR
    end
  end
end
