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
        search('som', %w{some words match sometimes}).should == %w{some sometimes}
      end

      test "matches first non underscore string" do
        first_search('wo', %w{some work wobbles}).should == 'work'
      end

      test "matches non underscore symbols" do
        search(:som, [:some, :words, :match, :sometimes]).should == [:some, :sometimes]
        search('som', [:some, :words, :match, :sometimes]).should == [:some, :sometimes]
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

      test "only matches exact match if multiple matches that start with exact match" do
        search('bl', %w{bl blang bling}).should == ['bl']
        first_search('bl', %w{bl blang bling}).should == 'bl'
      end
    end
  end
end