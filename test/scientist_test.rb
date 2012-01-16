require File.join(File.dirname(__FILE__), 'test_helper')

describe "Scientist" do
  before_all {
    Runner.in_shell = nil
    eval <<-EOF
    module Blah
      def blah(arg1, options={})
        [arg1, options]
      end
      def splat_blah(*args)
        args
      end
      def default_blah(arg1, arg2=default, options={})
        [arg1, arg2, options]
      end
      def default; 'some default'; end
      def default_option(options={})
        options
      end
    end
    EOF
    @opt_cmd = Object.new.extend Blah
  }

  def command(hash, args)
    hash = {:name=>'blah', :lib=>'bling', :options=>{:force=>:boolean, :level=>2}}.merge(hash)
    @cmd = Command.new hash
    @cmd.instance_variable_set("@file_parsed_args", true) if hash[:file_parsed_args]
    Scientist.redefine_command(@opt_cmd, @cmd)
    @opt_cmd.send(hash[:name], *args)
  end

  def command_with_arg_size(*args)
    command({:args=>2}, args)
  end

  def command_with_args(*args)
    command({:args=>[['arg1'],['options', {}]]}, args)
  end

  def basic_command(hash, args)
    command({:name=>'splat_blah', :args=>'*'}.merge(hash), args)
  end

  def command_with_splat_args(*args)
    command({:name=>'splat_blah', :args=>'*'}, args)
  end

  def command_with_arg_defaults(*args)
    arg_defaults = [%w{arg1}, %w{arg2 default}, %w{options {}}]
    command({:name=>'default_blah', :file_parsed_args=>true, :args=>arg_defaults}, args)
  end

  def args_are_equal(args, array)
    command_with_args(*args).should == array
    command_with_arg_size(*args).should == array
    command_with_splat_args(*args).should == array
  end

  def all_commands
    [:command_with_args, :command_with_arg_size, :command_with_splat_args]
  end

  describe "all commands" do
    it "translate arg and options as one string" do
      args_are_equal ['a1 -f'], ['a1', {:force=>true, :level=>2}]
    end

    it "translate arg and stringified options" do
      args_are_equal [:cool, '-l3'], [:cool, {:level=>3}]
    end

    it "translate arg and normal hash options" do
      args_are_equal [:cool, {:ok=>true}], [:cool, {:ok=>true, :level=>2}]
    end

    it "translate stringified arg without options sets default options" do
      args_are_equal ['cool'], ['cool', {:level=>2}]
    end

    it "translate arg without options sets default options" do
      args_are_equal [:cool], [:cool, {:level=>2}]
    end

    it "with invalid options print errors and delete them" do
      all_commands.each do |cmd|
        capture_stderr {
          send(cmd, 'cool -f -z').should == ['cool', {:force=>true, :level=>2}]
        }.should =~/invalid.*z/
      end
    end

    it "print help with help option" do
      all_commands.each do |cmd|
        Boson.expects(:invoke).with(:usage, anything, anything)
        send(cmd, '-h')
      end
    end
  end

  describe "command" do
    describe "with arg defaults" do
      it "sets defaults with stringified args" do
        command_with_arg_defaults('1').should == ["1", "some default", {:level=>2}]
      end

      it "sets defaults with normal args" do
        command_with_arg_defaults(1).should == [1, "some default", {:level=>2}]
      end

      it "sets default if optional arg is a valid option" do
        command_with_arg_defaults("cool -f").should == ["cool", "some default", {:level=>2, :force=>true}]
      end

      it "doesn't set defaults if not needed" do
        command_with_arg_defaults(1, 'nada').should == [1, "nada", {:level=>2}]
      end

      it "prints error for invalid defaults" do
        arg_defaults = [%w{arg1}, %w{arg2 invalidzzz}, %w{options {}}]
        capture_stderr {
          command({:name=>'default_blah', :file_parsed_args=>true, :args=>arg_defaults}, [1])
        }.should =~ /Error.*position 2/
      end
    end

    describe "prints error" do
      it "with option error" do
        capture_stderr { command_with_args('a1 -l') }.should =~ /Error.*level/
      end

      it "with no argument defined for options" do
        assert_error(OptionCommand::CommandArgumentError, '2 for 1') { command({:args=>1}, 'ok') }
      end
    end

    it "translates stringfied args + options starting at second arg" do
      command_with_arg_defaults(1, 'nada -l3').should == [1, "nada", {:level=>3}]
    end

    it "with leading option-like args are translated as arguments" do
      command_with_args('-z -f').should == ["-z", {:force=>true, :level=>2}]
      command_with_args('--blah -f').should == ['--blah', {:force=>true, :level=>2}]
    end

    it "with splat args does not raise error for too few or many args" do
      [[], [''], [1,2,3], ['1 2 3']].each do |args|
        should.not.raise { command_with_splat_args *args }
      end
    end

    it "with debug option prints debug" do
      capture_stdout { command_with_args("-v ok") }.should =~ /Arguments.*ok/
    end

    it "with pretend option prints arguments and returns early" do
      Scientist.expects(:process_result).never
      capture_stdout { command_with_args("-p ok") }.should =~ /Arguments.*ok/
    end

    it "with not enough args raises CommandArgumentError" do
      args = [OptionCommand::CommandArgumentError, '0 for 1']
      assert_error(*args) { command_with_args }
      assert_error(*args) { command_with_args '' }
      assert_error(*args) { command_with_arg_size }
      assert_error(*args) { command_with_arg_size '' }
    end

    it "with too many args raises CommandArgumentError" do
      args3 = [ArgumentError, '3 for 2']
      args4 = [OptionCommand::CommandArgumentError, '4 for 2']
      assert_error(*args3) { command_with_args 1,2,3 }
      assert_error(*args4) { command_with_args '1 2 3' }
      assert_error(*args3) { command_with_arg_size 1,2,3 }
      assert_error(*args4) { command_with_arg_size '1 2 3' }
    end
  end

  describe "command with default option" do
    before_all { @cmd_attributes = {:name=>'default_option', :default_option=>'level', :args=>1} }

    it "parses normally from irb" do
      command(@cmd_attributes, '-f --level=3').should == {:level=>3, :force=>true}
    end

    it "parses normally from cmdline" do
      Runner.expects(:in_shell?).times(2).returns true
      command(@cmd_attributes, ['--force', '--level=3']).should == {:level=>3, :force=>true}
    end

    it "parses no arguments normally" do
      command(@cmd_attributes, '').should == {:level=>2}
    end

    it "parses ruby arguments normally" do
      command(@cmd_attributes, [{:force=>true, :level=>10}]).should == {:level=>10, :force=>true}
    end

    it "prepends correctly from irb" do
      command(@cmd_attributes, '3 -f').should == {:level=>3, :force=>true}
    end

    it "prepends correctly from cmdline" do
      Runner.expects(:in_shell?).times(2).returns true
      command(@cmd_attributes, ['3','-f']).should == {:level=>3, :force=>true}
    end
  end

  it "redefine_command prints error for command with nonexistant method" do
    capture_stderr {
      Scientist.redefine_command Object.new, Command.new(:name=>'blah', :lib=>'blah')
    }.should =~ /Error: No method.*'blah'/
  end

  after_all { Runner.in_shell = false }
end
