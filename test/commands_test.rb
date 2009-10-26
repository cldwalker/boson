require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class CommandsTest < Test::Unit::TestCase
    before(:all) {
        @higgs = Boson.main_object
        if Boson.libraries.size.zero?
          reset_boson
          ancestors = class <<Boson.main_object; self end.ancestors
          # allows running just this test file
          Manager.load Runner.default_libraries unless ancestors.include?(Boson::Commands::Core)
        end
    }

    def render_expects(&block)
      View.expects(:render).with(&block)
    end

    context "libraries" do
      before(:all) {
        Boson.libraries << Boson::Library.new(:name=>'blah')
        Boson.libraries << Boson::Library.new(:name=>'another', :module=>"Cool")
      }

      test "lists all when given no argument" do
        render_expects {|*args| args[0].size == Boson.libraries.size }
        @higgs.libraries
      end

      test "searches with a given search field" do
        render_expects {|*args| args[0] == [Boson.library('another')]}
        @higgs.libraries('Cool', :query_fields=>[:module])
      end
    end

    context "commands" do
      before(:all) {
        Boson.commands << Command.create('some', Library.new(:name=>'thing'))
        Boson.commands << Command.create('and', Library.new(:name=>'this'))
      }

      test "lists all when given no argument" do
        render_expects {|*args| args[0].size == Boson.commands.size }
        @higgs.commands
      end

      test "searches with a given search field" do
        render_expects {|*args| args[0] == [Command.find('and')]}
        @higgs.commands('this', :query_fields=>[:lib])
      end
    end
  end
end
