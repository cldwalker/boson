require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class CommandsTest < Test::Unit::TestCase
    before(:all) {
      @higgs = Object.new.extend Boson::Commands::Core
    }
    test "unloaded_libraries detects libraries under commands directory" do
      Dir.stubs(:[]).returns(['./commands/lib.rb', './commands/lib2.rb'])
      @higgs.unloaded_libraries.should == ['lib', 'lib2']
    end

    test "unloaded_libraries detect libraries in :libraries config" do
      with_config :libraries=>{'yada'=>{:detect_methods=>false}} do
        @higgs.unloaded_libraries.should == ['yada']
      end
    end
  end
end