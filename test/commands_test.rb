require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class CommandsTest < Test::Unit::TestCase
    before(:all) {
      reset_boson
      @higgs = Object.new.extend Boson::Commands::Core
    }
    test "unloaded_libraries detects libraries under commands directory" do
      Dir.stubs(:[]).returns(['./commands/lib.rb', './commands/lib2.rb'])
      @higgs.unloaded_libraries.should == ['lib', 'lib2']
    end

    test "unloaded_libraries detect libraries in :libraries config" do
      with_config :libraries=>{'yada'=>{}} do
        @higgs.unloaded_libraries.should == ['yada']
      end
    end

    def render_expects(&block)
      @higgs.expects(:render).with(&block)
    end

    context "libraries" do
      before(:all) {
        Boson.libraries << Boson::Library.new(:name=>'blah')
        Boson.libraries << Boson::Library.new(:name=>'another', :module=>"Cool")
      }

      test "lists all when given no argument" do
        render_expects {|*args| args[0].size == 2}
        @higgs.libraries
      end

      test "searches by name field by default" do
        render_expects {|*args| args[0] == [Boson.library('blah')]}
        @higgs.libraries 'blah'
      end

      test "searches with a given search field" do
        render_expects {|*args| args[0] == [Boson.library('another')]}
        @higgs.libraries('Cool', :search_field=>:module)
      end
    end

    context "commands" do
      before(:all) {
        Boson.commands << Command.create('some', Library.new(:name=>'thing'))
        Boson.commands << Command.create('and', Library.new(:name=>'this'))
      }

      test "lists all when given no argument" do
        render_expects {|*args| args[0].size == 2}
        @higgs.commands
      end

      test "searches by name field by default" do
        render_expects {|*args| args[0] == [Boson.command('some')]}
        @higgs.commands('some')
      end

      test "searches with a given search field" do
        render_expects {|*args| args[0] == [Boson.command('and')]}
        @higgs.commands('this', :search_field=>:lib)
      end
    end
  end
end
