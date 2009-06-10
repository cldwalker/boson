require File.join(File.dirname(__FILE__), 'test_helper')

class Boson::SearchableArrayTest < Test::Unit::TestCase
  before(:all) { 
    @sarray = Boson::SearchableArray.new([{:name=>'dog', :color=>'red', :num=>1}, {:name=>'cat', :color=>'blue', :num=>1}])
  }
  context "search" do
    test "returns back array if no term given" do
      @sarray.search.should == @sarray
    end

    test "searches default field when given a string" do
      @sarray.search('dog').should == @sarray.slice(0,1)
    end

    test "can be a regular expression" do
      @sarray.search('g$').should == @sarray.slice(0,1)
    end

    test "searches by a partial field name by sorted order of search fields" do
      @sarray.search(:n=>'cat').should == @sarray.slice(1,1)
    end

    test "searches by a full field name" do
      @sarray.search(:color=>'blue').should == @sarray.slice(1,1)
    end

    test "ands multiple search terms" do
      @sarray.search(:color=>'e', :name=>'do').should == @sarray.slice(0,1)
    end

    test "can have default search terms" do
      @sarray.search(nil, :name=>'do').should == @sarray.slice(0,1)
    end
  end

  test "find_by searches by an exact value" do
    @sarray.find_by(:name=>'do').should == nil
  end

  test "find_by returns first result" do
    @sarray.find_by(:num=>1).should == @sarray[0]
  end

  test "find_by returns nil if no results" do
    @sarray.find_by(:num=>10).should == nil
  end

  test "find_by and search can be called one after the other" do
    @sarray.find_by(:num=>1).should == @sarray[0]
    @sarray.search(:n=>'dog').should == @sarray.slice(0,1)
  end
end
