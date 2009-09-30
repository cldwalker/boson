require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class OptionParserTest < Test::Unit::TestCase
  def create(opts)
    @opt = OptionParser.new(opts)
  end
  
  def parse(*args)
    @non_opts = []
    @opt.parse(args.flatten)
  end
  
  context "IndifferentAccessHash" do
    before(:each) {
      @hash = IndifferentAccessHash.new 'foo' => 'bar', 'baz' => 'bee'
    }
    it "can access values indifferently" do
      @hash['foo'].should == 'bar'
      @hash[:foo].should  == 'bar'
      @hash.values_at(:foo, :baz).should == ['bar', 'bee']
    end

    it "can be initialized with either strings or symbols and be equal" do
      hash2 = IndifferentAccessHash.new :foo=>'bar', :baz=>'bee'
      @hash.should == hash2
    end

    it "returns keys as symbols by default" do
      @hash.should == {:foo=>'bar', :baz=>'bee'}
    end

    it "can set values indifferently" do
      @hash['foo'] = 'duh'
      @hash[:foo].should == 'duh'
      @hash[:baz] = 'wasp'
      @hash['baz'].should == 'wasp'
    end
  end

  context "naming" do
    it "automatically aliases long options with their first letter" do
      create "--foo" => true
      parse("-f")["foo"].should == true
    end

    it "automatically aliases two options with same first letters by aliasing alphabetical first with lowercase and second with uppercase" do
      create :verbose=>:boolean, :vertical=>:string, :verz=>:boolean
      parse('-v', '-V','2').should == {:verbose=>true, :vertical=>'2'}
    end
    
    it "doesn't auto-alias options that have multiple names given" do
      create ["--foo", "--bar"] => :boolean
      parse("-f")["foo"].should == nil
    end

    it "allows aliases to be symbols or strings" do
      create [:foo, :bar, 'baz'] =>:string
      parse("--foo", "12")[:foo].should == "12"
      parse("--bar", "12")[:foo].should == "12"
      parse("--baz", "12")[:foo].should == "12"
    end
    
    it "allows multiple aliases for a given opt" do
      create ["--foo", "--bar", "--baz"] => :string
      parse("--foo", "12")["foo"].should == "12"
      parse("--bar", "12")["foo"].should == "12"
      parse("--baz", "12")["foo"].should == "12"
    end
    
    it "allows custom short names" do
      create "-f" => :string
      parse("-f", "12").should == {:f => "12"}
    end

    it "allows capital short names" do
      create :A => :boolean
      parse("-A")[:A].should == true
    end

    it "allows capital short aliases" do
      create [:awesome, :A] => :string
      parse("--awesome", "bar")[:awesome].should == 'bar'
      parse("-A", "bar")[:awesome].should == 'bar'
    end

    it "allows custom short aliases" do
      create ["--bar", "-f"] => :string
      parse("-f", "12").should == {:bar => "12"}
    end
    
    it "allows humanized opt name" do
      create 'foo' => :string, :bar => :required
      parse("-f", "1", "-b", "2").should == {:foo => "1", :bar => "2"}
    end

    it "allows humanized symbol opt name" do
      create :foo=>:string
      parse('-f','1').should == {:foo=>'1'}
    end

    it "doesn't allow alias to override another option" do
      create :foo=>:string, [:bar, :foo]=>:boolean
      parse("--foo", "boo")[:foo].should == 'boo'
    end

    it "doesn't recognize long opt format for a opt that is originally short" do
      create 'f' => :string
      parse("-f", "1").should == {:f => "1"}
      parse("--f", "1").should == {}
    end
    
    it "accepts --[no-]opt variant for booleans, setting false for value" do
      create "--foo" => :boolean
      parse("--no-foo")["foo"].should == false
      parse("--foo")["foo"].should == true
    end
    
    it "will prefer 'no-opt' variant over inverting 'opt' if explicitly set" do
      create "--no-foo" => true
      parse("--no-foo")["no-foo"].should == true
    end
    
  end

  context "option values can be set with" do
    it "a opt=<value> assignment" do
      create "--foo" => :required
      parse("--foo=12")["foo"].should == "12"
      parse("-f=12")["foo"].should == "12"
      parse("--foo=bar=baz")["foo"].should == "bar=baz"
      parse("--foo=sentence with spaces")["foo"].should == "sentence with spaces"
    end
  
    it "a -nXY assignment" do
      create "--num" => :required
      parse("-n12")["num"].should == "12"
    end
  
    it "conjoined short options" do
      create "--foo" => true, "--bar" => true, "--app" => true
      opts = parse "-fba"
      opts["foo"].should == true
      opts["bar"].should == true
      opts["app"].should == true
    end
  
    it "conjoined short options with argument" do
      create "--foo" => true, "--bar" => true, "--app" => :required
      opts = parse "-fba", "12"
      opts["foo"].should == true
      opts["bar"].should == true
      opts["app"].should == "12"
    end
  end

  context "parse" do
    it "extracts non-option arguments" do
      create "--foo" => :required, "--bar" => true
      parse("foo", "bar", "--baz", "--foo", "12", "--bar", "-T", "bang").should == {
        :foo => "12", :bar => true
      }
      @opt.leading_non_opts.should == ["foo", "bar", "--baz"]
      @opt.trailing_non_opts.should == ["-T", "bang"]
      @opt.non_opts.should == ["foo", "bar", "--baz", "-T", "bang"]
    end

    context "with parse flag" do
      it ":delete_invalid_opts deletes and warns of invalid options" do
        create(:foo=>:boolean)
        capture_stderr {
          @opt.parse(%w{-f -d ok}, :delete_invalid_opts=>true)
        }.should =~ /Deleted invalid option '-d'/
        @opt.non_opts.should == ['ok']
      end

      it ":opts_before_args only allows options before args" do
        create(:foo=>:boolean)
        @opt.parse(%w{ok -f}, :opts_before_args=>true).should == {}
        @opt.parse(%w{-f ok}, :opts_before_args=>true).should == {:foo=>true}
      end
    end

    context "with no arguments" do
      it "and no options returns an empty hash" do
        create({})
        parse.should == {}
      end

      it "and several options returns an empty hash" do
        create "--foo" => :boolean, "--bar" => :string
        parse.should == {}
      end
    end
  end

  context "option hashes" do
    it "make hash keys available as symbols as well" do
      create "--foo" => :string
      parse("--foo", "12")[:foo].should == "12"
    end

    it "don't set nonexistant options" do
      create "--foo" => :boolean
      parse("--foo")["bar"].should == nil
      opts = parse
      opts["foo"].should == nil
    end
  end

  it ":required type raises an error if it isn't given" do
    create "--foo" => :required, "--bar" => :string
    assert_error(OptionParser::Error, 'no value.*required.*foo') { parse("--bar", "str") }
  end
  
  context ":string type" do
    before :each do
      create "--foo" => :string, "--bar" => :string
    end

    it "doesn't set nonexistant options" do
      parse("--bling")[:bar].should == nil
    end

    it "sets values correctly" do
      parse("--foo", "12")[:foo].should == "12"
      parse("--bar", "12")[:bar].should == "12"
    end

    it "raises error if passed another valid option" do
      assert_error(OptionParser::Error, "cannot pass.*'foo'") { parse("--foo", "--bar") }
    end

    it "raises error if not passed a value" do
      assert_error(OptionParser::Error, "no value.*'foo'") { parse("--foo") }
    end

    it "overwrites earlier values with later values" do
      parse("--foo", "12", "--foo", "13")[:foo].should == "13"
    end
  end
  
  context ":string type with :values attribute" do
    before(:all ) { create :foo=>{:type=>:string, :values=>%w{angola abu abib}} }
    it "auto aliases if a match exists" do
      parse("-f", "an")[:foo].should == 'angola'
    end

    it "auto aliases first sorted match" do
      parse("-f", "a")[:foo].should == 'abib'
    end

    it "raises error if option doesn't auto alias or match given values" do
      assert_error(OptionParser::Error, "invalid.*'z'") { parse("-f", "z") }
    end

    it "doesn't raise error for a nonmatch if enum is false" do
      create :foo=>{:type=>:string, :values=>%w{angola abu abib}, :enum=>false}
      parse("-f", "z")[:foo].should == 'z'
    end
  end
  
  context ":string type with default value" do
    before(:each) do
      create "--branch" => "master"
    end
    
    it "should get the specified value" do
      parse("--branch", "bugfix").should == { :branch => "bugfix" }
    end
  
    it "should get the default value when not specified" do
      parse.should == { :branch => "master" }
    end
  end
  
  context ":numeric type" do
    before(:each) do
      create "n" => :numeric, "m" => 5
    end
    
    it "supports numeric defaults" do
      parse["m"].should == 5
    end
    
    it "converts values to numeric types" do
      parse("-n", "3", "-m", ".5").should == {:n => 3, :m => 0.5}
    end
    
    it "raises error when value isn't numeric" do
	  assert_error(OptionParser::Error, "expected numeric value for.*'n'") { parse("-n", "foo") }
    end
    
    it "raises error when opt is present without value" do
	    assert_error(OptionParser::Error, "no value.*'n'") { parse("-n") }
    end
  end

  context ":array type" do
    before(:all) {
      create :a=>:array, :b=>[1,2,3], :c=>{:type=>:array, :values=>%w{foo fa bar zebra}},
        :d=>{:type=>:array, :split=>" "}
    }

    it "supports array defaults" do
      parse[:b].should == [1,2,3]
    end

    it "converts comma delimited values to an array" do
      parse("-a","1,2,5")[:a].should == %w{1 2 5}
    end

    it "raises error when option has no value" do
      assert_error(OptionParser::Error, "no value.*'a'") { parse("-a") }
    end

    it "auto aliases :values attribute" do
      parse("-c","f,b")[:c].should == %w{fa bar}
    end

    it "allows a configurable splitter" do
      parse("-d", "yogi berra")[:d].should == %w{yogi berra}
    end
  end

  context "option with attributes" do
    it "can get type from :type" do
      create :foo=>{:type=>:numeric}
      parse("-f", '3')[:foo] == 3
    end

    it "can get type and default from :default" do
      create :foo=>{:default=>[]}
      parse("-f", "1")[:foo].should == ['1']
      parse[:foo].should == []
    end

    it "assumes :boolean type if no type found" do
      create :foo=>{:some=>'params'}
      parse('-f')[:foo].should == true
    end
  end
  
  context "#formatted_usage" do
    def usage
      @opt.formatted_usage.split(" ").sort
    end
    
    it "outputs string args with sample values" do
      create "--repo" => :string, "--branch" => "bugfix", "-n" => 6
      usage.should == %w([--branch=bugfix] [--repo=REPO] [-n=6])
    end
    
    it "outputs numeric args with 'N' as sample value" do
      create "--iter" => :numeric
      usage.should == ["[--iter=N]"]
    end

    it "outputs array args with sample value" do
      create "--libs" => :array
      usage.should == ["[--libs=A,B,C]"]
    end
  end
end
end
