require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class ScientistTest < Test::Unit::TestCase
    before(:all) {
      unless ScientistTest.const_defined?(:Blah)
        Boson.send :remove_const, :BinRunner if Boson.const_defined?(:BinRunner)
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
      end
      @opt_cmd = Object.new.extend Blah
    }
    after(:all) { Runner.in_shell = false }

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

    ALL_COMMANDS = [:command_with_args, :command_with_arg_size, :command_with_splat_args]

    context "all commands" do
      test "translate arg and options as one string" do
        args_are_equal ['a1 -f'], ['a1', {:force=>true, :level=>2}]
      end

      test "translate arg and stringified options" do
        args_are_equal [:cool, '-l3'], [:cool, {:level=>3}]
      end

      test "translate arg and normal hash options" do
        args_are_equal [:cool, {:ok=>true}], [:cool, {:ok=>true, :level=>2}]
      end

      test "translate stringified arg without options sets default options" do
        args_are_equal ['cool'], ['cool', {:level=>2}]
      end

      test "translate arg without options sets default options" do
        args_are_equal [:cool], [:cool, {:level=>2}]
      end

      test "with invalid options print errors and delete them" do
        ALL_COMMANDS.each do |cmd|
          capture_stderr {
            send(cmd, 'cool -f -z').should == ['cool', {:force=>true, :level=>2}]
          }.should =~/invalid.*z/
        end
      end

      test "print help with help option" do
        ALL_COMMANDS.each do |cmd|
          Boson.expects(:invoke).with(:usage, anything, anything)
          send(cmd, '-h')
        end
      end
    end

    context "command" do
      context "with arg defaults" do
        test "sets defaults with stringified args" do
          command_with_arg_defaults('1').should == ["1", "some default", {:level=>2}]
        end

        test "sets defaults with normal args" do
          command_with_arg_defaults(1).should == [1, "some default", {:level=>2}]
        end

        test "sets default if optional arg is a valid option" do
          command_with_arg_defaults("cool -f").should == ["cool", "some default", {:level=>2, :force=>true}]
        end

        test "doesn't set defaults if not needed" do
          command_with_arg_defaults(1, 'nada').should == [1, "nada", {:level=>2}]
        end

        test "prints error for invalid defaults" do
          arg_defaults = [%w{arg1}, %w{arg2 invalidzzz}, %w{options {}}]
          capture_stderr {
            command({:name=>'default_blah', :file_parsed_args=>true, :args=>arg_defaults}, [1])
          }.should =~ /Error.*position 2/
        end
      end

      context "prints error" do
        test "with option error" do
          capture_stderr { command_with_args('a1 -l') }.should =~ /Error.*level/
        end

        test "with unexpected error in render" do
          Scientist.expects(:render?).raises("unexpected")
          capture_stderr { command_with_args('a1') }.should =~ /Error.*unexpected/
        end

        test "with no argument defined for options" do
          assert_error(OptionCommand::CommandArgumentError, '2 for 1') { command({:args=>1}, 'ok') }
        end
      end

      test "translates stringfied args + options starting at second arg" do
        command_with_arg_defaults(1, 'nada -l3').should == [1, "nada", {:level=>3}]
      end

      test "with leading option-like args are translated as arguments" do
        command_with_args('-z -f').should == ["-z", {:force=>true, :level=>2}]
        command_with_args('--blah -f').should == ['--blah', {:force=>true, :level=>2}]
      end

      test "with splat args does not raise error for too few or many args" do
        [[], [''], [1,2,3], ['1 2 3']].each do |args|
          assert_nothing_raised { command_with_splat_args *args }
        end
      end

      test "with debug option prints debug" do
        capture_stdout { command_with_args("-v ok") } =~ /Arguments.*ok/
      end

      test "with pretend option prints arguments and returns early" do
        Scientist.expects(:render_or_raw).never
        capture_stdout { command_with_args("-p ok") } =~ /Arguments.*ok/
      end

      test "with not enough args raises CommandArgumentError" do
        args = [OptionCommand::CommandArgumentError, '0 for 1']
        assert_error(*args) { command_with_args }
        assert_error(*args) { command_with_args '' }
        assert_error(*args) { command_with_arg_size }
        assert_error(*args) { command_with_arg_size '' }
      end

      test "with too many args raises CommandArgumentError" do
        args3 = [ArgumentError, '3 for 2']
        args4 = [OptionCommand::CommandArgumentError, '4 for 2']
        assert_error(*args3) { command_with_args 1,2,3 }
        assert_error(*args4) { command_with_args '1 2 3' }
        assert_error(*args3) { command_with_arg_size 1,2,3 }
        assert_error(*args4) { command_with_arg_size '1 2 3' }
      end
    end

    def command_with_render(*args)
      basic_command({:render_options=>{:fields=>{:values=>['f1', 'f2']}} }, args)
    end

    def render_expected(options=nil)
      View.expects(:render).with(anything, options || anything, false)
    end

    context "render" do
      test "called for command with render_options" do
        render_expected
        command_with_render('1')
      end

      test "called for command without render_options and --render" do
        render_expected
        command_with_args('--render 1')
      end

      test "not called for command with render_options and --render" do
        Boson.expects(:invoke).never
        command_with_render('--render 1')
      end

      test "not called for command without render_options" do
        Boson.expects(:invoke).never
        command_with_args('1')
      end
    end

    context "command renders" do
      test "with basic render options" do
        render_expected :fields => ['f1', 'f2']
        command_with_render("--fields f1,f2 ab")
      end

      test "without non-render options" do
        render_expected :fields=>['f1']
        Scientist.expects(:render?).returns(true)
        args = ["--render --fields f1 ab"]
        basic_command({:render_options=>{:fields=>{:values=>['f1', 'f2']}} }, args)
      end

      test "with user-defined render options" do
        render_expected :fields=>['f1'], :foo=>true
        args = ["--foo --fields f1 ab"]
        basic_command({:render_options=>{:foo=>:boolean, :fields=>{:values=>['f1', 'f2']}} }, args)
      end

      test "with non-hash user-defined render options" do
        render_expected :fields=>['f1'], :foo=>true
        args = ["--foo --fields f1 ab"]
        basic_command({:render_options=>{:foo=>:boolean, :fields=>%w{f1 f2 f3}} }, args)
      end
    end

    context "command with default option" do
      before(:all) { @cmd_attributes = {:name=>'default_option', :default_option=>'level', :args=>1} }

      test "parses normally from irb" do
        command(@cmd_attributes, '-f --level=3').should == {:level=>3, :force=>true}
      end

      test "parses normally from cmdline" do
        Runner.expects(:in_shell?).times(2).returns true
        command(@cmd_attributes, ['--force', '--level=3']).should == {:level=>3, :force=>true}
      end

      test "parses no arguments normally" do
        command(@cmd_attributes, '').should == {:level=>2}
      end

      test "parses ruby arguments normally" do
        command(@cmd_attributes, [{:force=>true, :level=>10}]).should == {:level=>10, :force=>true}
      end

      test "prepends correctly from irb" do
        command(@cmd_attributes, '3 -f').should == {:level=>3, :force=>true}
      end

      test "prepends correctly from cmdline" do
        Runner.expects(:in_shell?).times(2).returns true
        command(@cmd_attributes, ['3','-f']).should == {:level=>3, :force=>true}
      end
    end

    test "optionless command renders" do
      render_expected :fields=>['f1']
      command({:args=>2, :options=>nil, :render_options=>{:fields=>:array}}, ["--fields f1 ab ok"])
    end

    context "global options:" do
      def local_and_global(*args)
        Scientist.stubs(:render?).returns(false) # turn off rendering caused by :render_options
        @non_opts = basic_command(@command_options, args)
        @non_opts.slice!(-1,1) << Scientist.global_options
      end

      before(:all) {
        @command_options = {:options=>{:do=>:boolean, :foo=>:boolean},
        :render_options=>{:dude=>:boolean}}
        @expected_non_opts = [[], ['doh'], ['doh'], [:doh]]
      }

      test "local option overrides global one" do
        ['-d', 'doh -d','-d doh', [:doh, '-d']].each_with_index do |args, i|
          local_and_global(*args).should == [{:do=>true}, {}]
          @non_opts.should == @expected_non_opts[i]
        end
      end

      test "global option before local one is valid" do
        args_arr = ['--dude -f', '--dude doh -f', '--dude -f doh', [:doh, '--dude -f']]
        args_arr.each_with_index do |args, i|
          local_and_global(*args).should == [{:foo=>true}, {:dude=>true}]
          @non_opts.should == @expected_non_opts[i]
        end
      end

      test "delete_options deletes global options" do
        local_and_global('--delete_options=r,p -rp -f').should ==
          [{:foo=>true}, {:delete_options=>["r", "p"]}]
      end

      test "global option after local one is invalid" do
        args_arr = ['-f --dude', '-f doh --dude', '-f --dude doh', [:doh, '-f --dude'] ]
        args_arr.each_with_index do |args, i|
          capture_stderr {
            local_and_global(*args).should == [{:foo=>true}, {}]
            @non_opts.should == @expected_non_opts[i]
          }.should =~ /invalid.*dude/
        end
      end

      test "--global option adds additional global options" do
        local_and_global('-g=dude -d').should == [{:do=>true}, {:dude=>true, :global=>'dude'}]
        local_and_global('-g "r dude" -d').should == [{:do=>true},
          {:global=>"r dude", :dude=>true, :render=>true}]
      end
    end

  end
end
