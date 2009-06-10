require File.join(File.dirname(__FILE__), 'test_helper')

class Boson::SearchableArrayTest < Test::Unit::TestCase
  before(:all) { 
    @sarray = Boson::SearchableArray.new([{:name=>'dog', :color=>'red', :num=>1}, {:name=>'cat', :color=>'blue', :num=>2}])
  }

  test "search returns back array if no term given" do
    @sarray.search.should == @sarray
  end

  test "search searches default field when given a string" do
    @sarray.search('dog').should == @sarray.slice(0,1)
  end

  test "search can be a regular expression" do
    @sarray.search('g$').should == @sarray.slice(0,1)
  end

  test "search searches by a partial field name by sorted order of search fields" do
    @sarray.search(:n=>'cat').should == @sarray.slice(1,1)
  end
  
  test "search searches by a full field name" do
    @sarray.search(:color=>'blue').should == @sarray.slice(1,1)
  end

  test "search ands multiple search terms" do
    @sarray.search(:color=>'e', :name=>'do').should == @sarray.slice(0,1)
  end

  test "search can have default search terms" do
    @sarray.search(nil, :name=>'do').should == @sarray.slice(0,1)
  end
end
