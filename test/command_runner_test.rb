require File.dirname(__FILE__) + '/test_helper'
require 'boson/command_runner'

class MyCommandRunner < Boson::CommandRunner
  desc "This is a small"
  def small(*args)
    p args
  end

  option :spicy, type: :boolean, desc: 'hot'
  desc "This is a medium"
  def medium(arg=nil, opts={})
    p [arg, opts]
  end

  def mini
  end

  private
  def no_run
  end
end

describe "CommandRunner" do
  before_all { $0 = 'my_command'; MyCommandRunner.init([]) }

  before {
    MyCommandRunner.expects(:init)
  }

  def my_command(cmd='')
    capture_stdout do
      MyCommandRunner.start cmd.split(/\s+/)
    end
  end

  it "prints generic usage by default" do
    my_command.should =~ /^Usage: my_command COMMAND/
  end

  describe "for -h COMMAND" do
    it "prints help for descriptionless command" do
      my_command('-h mini').should == <<-STR
Usage: my_command mini

Description:
  TODO
STR
    end

    it "prints help for optionless command" do
      my_command('-h small').should == <<-STR
Usage: my_command small [*args]

Description:
  This is a small
STR
    end

    it "prints help for command with options" do
      my_command('-h medium').should == <<-STR
Usage: my_command medium [arg="nil"]

Options:
  -s, --spicy  hot

Description:
  This is a medium
STR
    end

    it "prints error message for nonexistant command" do
      my_command('-h blarg').chomp.should ==
        'Could not find command "blarg"'
    end
  end

  it "call command with options correctly" do
    my_command('medium 1 --spicy').chomp.should == '["1", {:spicy=>true}]'
  end

  it "call optionless command correctly" do
    my_command('small 1 2').chomp.should == '["1", "2"]'
  end

  it "calls command with too many args" do
    MyCommandRunner.expects(:abort).with <<-STR.chomp
'medium' was called incorrectly.
medium [arg="nil"][--spicy]
STR
    my_command('medium 1 2 3')
  end
end
