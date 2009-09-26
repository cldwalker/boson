require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class HiggsTest < Test::Unit::TestCase
    before(:all) {
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
      end
      EOF
      @opt_cmd = Object.new.extend Blah
    }

    context "command" do
      def command(hash, args)
        hash = {:name=>'blah', :lib=>'bling', :options=>{:force=>:boolean, :level=>2}}.merge(hash)
        @cmd = Command.new hash
        @cmd.instance_variable_set("@file_parsed_args", true) if hash[:file_parsed_args]
        Higgs.create_option_command(@opt_cmd, @cmd)
        @opt_cmd.send(hash[:name], *args)
      end

      def command_with_arg_size(*args)
        command({:args=>2}, args)
      end

      def command_with_args(*args)
        command({:args=>[['arg1'],['options', {}]]}, args)
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

      context "with arg defaults" do
        test "sets defaults with stringified args" do
          command_with_arg_defaults('1').should == ["1", "some default", {:level=>2}]
        end

        test "sets defaults with normal args" do
          command_with_arg_defaults(1).should == [1, "some default", {:level=>2}]
        end

        test "doesn't set defaults if not needed" do
          command_with_arg_defaults(1, 'nada').should == [1, "nada", {:level=>2}]
        end
      end

      test "translated stringfied args + options starting at second arg" do
        command_with_arg_defaults(1, 'nada -l3').should == [1, "nada", {:level=>3}]
      end

      test "with invalid option syntax prints error" do
        capture_stderr { command_with_args('a1 -l') }.should =~ /Error.*level/
      end

      test "with invalid default args prints error" do
        arg_defaults = [%w{arg1}, %w{arg2 invalidzzz}, %w{options {}}]
        capture_stderr {
          command({:name=>'default_blah', :file_parsed_args=>true, :args=>arg_defaults}, [1])
        }.should =~ /Error.*position 2/
      end

      test "with unexpected error in option mapping catches and prints it" do
        Higgs.stubs(:command_options).raises("unexpected")
        capture_stderr { command_with_args('a1') }.should =~ /Error.*unexpected/
      end

      context "for all cases" do
        test "translates arg and options as one string" do
          args_are_equal ['a1 -f'], ['a1', {:force=>true, :level=>2}]
        end

        test "translates arg and stringified options" do
          args_are_equal [:cool, '-l3'], [:cool, {:level=>3}]
        end

        test "translates arg and normal hash options" do
          args_are_equal [:cool, {:ok=>true}], [:cool, {:ok=>true}]
        end

        test "translates stringified arg without options sets default options" do
          args_are_equal ['cool'], ['cool', {:level=>2}]
        end

        test "translates arg without options sets default options" do
          args_are_equal [:cool], [:cool, {:level=>2}]
        end

        test "with invalid options prints error and deletes them" do
          expected = ['cool', {:force=>true, :level=>2}]
          [:command_with_args, :command_with_arg_size, :command_with_splat_args].each do |meth|
            capture_stderr {
              send(meth, 'cool -f -z').should == expected
            }.should =~/Invalid.*z/
          end
        end
      end

      test "with option-like args before valid opts are kept as arguments" do
        command_with_args('-z -f').should == ["-z", {:force=>true, :level=>2}]
        command_with_args('--verbose -l3').should == ['--verbose', {:level=>3}]
      end

      test "with splat args does not raise error for too few or many args" do
        [[], [''], [1,2,3], ['1 2 3']].each do |args|
          assert_nothing_raised { command_with_splat_args *args }
        end
      end

      test "with not enough args raises error" do
        args = [ArgumentError, '0 for 1']
        assert_error(*args) { command_with_args }
        assert_error(*args) { command_with_args '' }
        assert_error(*args) { command_with_arg_size }
        assert_error(*args) { command_with_arg_size '' }
      end

      test "with too many args raises error" do
        args = [ArgumentError, '3 for 2']
        assert_error(*args) { command_with_args 1,2,3 }
        assert_error(*args) { command_with_args '1 2 3' }
        assert_error(*args) { command_with_arg_size 1,2,3 }
        assert_error(*args) { command_with_arg_size '1 2 3' }
      end
    end
  end
end
