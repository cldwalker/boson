require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class UtilTest < Test::Unit::TestCase
    context "underscore_search" do
      def search(query, list)
        Util.underscore_search(query, list).sort {|a,b| a.to_s <=> b.to_s }
      end

      def first_search(query, list)
        Util.underscore_search(query, list, true)
      end

      test "matches non underscore strings" do
        search('some', %w{some words match sometimes}).should == %w{some sometimes}
      end

      test "matches first non underscore string" do
        first_search('wo', %w{some work wobbles}).should == 'work'
      end

      test "matches non underscore symbols" do
        search(:some, [:some, :words, :match, :sometimes]).should == [:some, :sometimes]
        search('some', [:some, :words, :match, :sometimes]).should == [:some, :sometimes]
      end

      test "matches underscore strings" do
        search('s_l', %w{some_long some_short some_lame}).should == %w{some_lame some_long}
      end

      test "matches first underscore string" do
        first_search('s_l', %w{some_long some_short some_lame}).should == 'some_long'
      end

      test "matches underscore symbols" do
        search(:s_l, [:some_long, :some_short, :some_lame]).should == [:some_lame, :some_long]
        search('s_l', [:some_long, :some_short, :some_lame]).should == [:some_lame, :some_long]
      end

      test "matches full underscore string" do
        search('some_long_name', %w{some_long_name some_short some_lame}).should == %w{some_long_name}
      end
    end
  end
end