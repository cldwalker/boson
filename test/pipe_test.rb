require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class PipeTest < Test::Unit::TestCase
    before(:all) {
      @hashes = [{:a=>'some', :b=>'thing'}, {:a=>:more, :b=>:yep}]
      Ab = Struct.new(:a, :b) unless PipeTest.const_defined?(:Ab)
      @objects = [Ab.new('some', 'thing'), Ab.new(:more, :yep)]
    }
    context "search_object" do

      test "searches one query" do
        [@hashes, @objects].each {|e|
          Pipe.search_object(e, :a=>'some').should == e[0,1]
        }
      end

      test "searches non-string values" do
        [@hashes, @objects].each {|e|
          Pipe.search_object(e, :a=>'more').should == e[1,1]
        }
      end

      test "searches multiple search terms" do
        [@hashes, @objects].each {|e|
          Pipe.search_object(e, :a=>'some', :b=>'yep').size.should == 2
        }
      end

      test "prints error for invalid search field" do
        capture_stderr { Pipe.search_object(@objects, :blah=>'blah') }.should =~ /failed.*'blah'/
      end
    end

    context "sort_object" do
      test "sorts objects with values of different types" do
        Pipe.sort_object(@objects, :a).should == @objects.reverse
      end

      test "sorts hashes with values of different types" do
        Pipe.sort_object(@hashes, :a).should == @hashes.reverse
      end

      test "sorts numeric values" do
        hashes = [{:a=>10, :b=>4}, {:a=>5, :b=>3}]
        Pipe.sort_object(hashes, :a).should == hashes.reverse
      end

      test "sorts and reverses sort" do
        Pipe.sort_object(@hashes, :a, true).should == @hashes
      end

      test "prints error for invalid sort field" do
        capture_stderr { Pipe.sort_object(@objects, :blah)}.should =~ /failed.*'blah'/
      end
    end
  end
end