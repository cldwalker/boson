require File.join(File.dirname(__FILE__), 'test_helper')

describe "Pipes" do
  before_all { ::Ab = Struct.new(:a, :b) }
  describe "query_pipe" do
    before_all {
      @hashes = [{:a=>'some', :b=>'thing'}, {:a=>:more, :b=>:yep}]
      @objects = [Ab.new('some', 'thing'), Ab.new(:more, :yep)]
    }

    it "searches one query" do
      [@hashes, @objects].each {|e|
        Pipes.query_pipe(e, :a=>'some').should == e[0,1]
      }
    end

    it "searches non-string values" do
      [@hashes, @objects].each {|e|
        Pipes.query_pipe(e, :a=>'more').should == e[1,1]
      }
    end

    it "searches multiple search terms" do
      [@hashes, @objects].each {|e|
        Pipes.query_pipe(e, :a=>'some', :b=>'yep').size.should == 2
      }
    end

    it "prints error for invalid search field" do
      capture_stderr { Pipes.query_pipe(@objects, :blah=>'blah') }.should =~ /failed.*'blah'/
    end
  end

  describe "sort_pipe" do
    before_all {
      @hashes = [{:a=>'some', :b=>'thing'}, {:a=>:more, :b=>:yep}]
      @objects = [Ab.new('some', 'thing'), Ab.new(:more, :yep)]
    }
    it "sorts objects with values of different types" do
      Pipes.sort_pipe(@objects, :a).should == @objects.reverse
    end

    it "sorts hashes with values of different types" do
      Pipes.sort_pipe(@hashes, :a).should == @hashes.reverse
    end

    it "sorts numeric values" do
      hashes = [{:a=>10, :b=>4}, {:a=>5, :b=>3}]
      Pipes.sort_pipe(hashes, :a).should == hashes.reverse
    end

    it "sorts numeric hash keys by string" do
      hashes = [{2=>'thing'}, {2=>'some'}]
      Pipes.sort_pipe(hashes, '2').should == hashes.reverse
    end

    it "sorts numeric hash keys by string" do
      Pipes.sort_pipe(@hashes, 'a').should == @hashes.reverse
    end

    it "prints error for invalid sort field" do
      capture_stderr { Pipes.sort_pipe(@objects, :blah)}.should =~ /failed.*'blah'/
    end
  end
end