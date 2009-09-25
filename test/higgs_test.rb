require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class HiggsTest < Test::Unit::TestCase
    before(:all) {
      eval <<-EOF
      module Blah
        def blah(arg1, options={})
          [arg1, options]
        end
      end
      EOF
      @opt_cmd = Object.new.extend Blah
    }

    context "command" do
      def option_command(*args)
        @cmd = Command.new :name=>'blah', :lib=>'bling', :options=>{:force=>:boolean, :level=>2},
          :args=>[['arg1'],['options', {}]]
        Higgs.create_option_command(@opt_cmd, @cmd)
        @opt_cmd.send(:blah, *args)
      end

      test "translates arg and options as one string" do
        option_command('a1 -f').should == ['a1', {:force=>true, :level=>2}]
      end

      test "translates arg and stringified options" do
        option_command(:cool, '-l3').should == [:cool, {:level=>3}]
      end

      test "translates arg and normal hash options" do
        option_command(:cool, :ok=>true).should == [:cool, {:ok=>true}]
      end

      test "translates stringified arg without options sets default options" do
        option_command('cool').should == ['cool', {:level=>2}]
      end

      test "translates arg without options sets default options" do
        option_command(:cool).should == [:cool, {:level=>2}]
      end

      test "with not enough args raises error" do
        assert_error(ArgumentError, '0 for 2') { option_command }
        assert_error(ArgumentError, '0 for 2') { option_command '' }
      end

      test "with too many args raises error" do
        assert_error(ArgumentError, '3 for 2') { option_command 1,2,3 }
        assert_error(ArgumentError, '3 for 2') { option_command '1 2 3' }
      end

      test "with invalid options prints error and deletes them" do
        capture_stderr { 
          option_command('cool -z -f').should == ['cool', {:force=>true, :level=>2}]
        }.should =~/Invalid.*z/
      end
    end
  end
end