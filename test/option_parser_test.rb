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

    it "allows custom short-name aliases" do
      create ["--bar", "-f"] => :string
      parse("-f", "12").should == {:bar => "12"}
    end
    
    it "allows humanized opt input" do
      create 'foo' => :string, :bar => :required
      parse("-f", "1", "-b", "2").should == {:foo => "1", :bar => "2"}
    end

    it "allows humanized symbol opt input" do
      create :foo=>:string
      parse('-f','1').should == {:foo=>'1'}
    end

    it "only creates alias for first opt if multiple options start with same letter" do
      create :verbose=>:boolean, :vertical=>:string
      parse('-v', '2').should == {:verbose=>true}
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
  
  it "accepts a opt=<value> assignment" do
    create "--foo" => :required
    parse("--foo=12")["foo"].should == "12"
    parse("-f=12")["foo"].should == "12"
    parse("--foo=bar=baz")["foo"].should == "bar=baz"
    parse("--foo=sentence with spaces")["foo"].should == "sentence with spaces"
  end
  
  it "accepts a -nXY assignment" do
    create "--num" => :required
    parse("-n12")["num"].should == "12"
  end
  
  it "accepts conjoined short options" do
    create "--foo" => true, "--bar" => true, "--app" => true
    opts = parse "-fba"
    opts["foo"].should == true
    opts["bar"].should == true
    opts["app"].should == true
  end
  
  it "accepts conjoined short options with argument" do
    create "--foo" => true, "--bar" => true, "--app" => :required
    opts = parse "-fba", "12"
    opts["foo"].should == true
    opts["bar"].should == true
    opts["app"].should == "12"
  end
  
  it "makes hash keys available as symbols as well" do
    create "--foo" => :string
    parse("--foo", "12")[:foo].should == "12"
  end

  it "deletes and warns of invalid options with :delete_invalid_opts" do
    create(:foo=>:boolean)
    capture_stderr {
      @opt.parse(%w{-f -d ok}, :delete_invalid_opts=>true)
    }.should =~ /Invalid option '-d'/
    @opt.non_opts.should == ['ok']
  end

  it "only allows options before args with :opts_before_args" do
    create(:foo=>:boolean)
    @opt.parse(%w{ok -f}, :opts_before_args=>true).should == {}
    @opt.parse(%w{-f ok}, :opts_before_args=>true).should == {:foo=>true}
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
  
    it "and a required opt raises an error" do
      create "--foo" => :required
      assert_raises(OptionParser::Error, "no value provided for required option '--foo'") { parse }
    end
  end
  
  it "doesn't set nonexistant options" do
    create "--foo" => :boolean
    parse("--foo")["bar"].should == nil
    opts = parse
    opts["foo"].should == nil
  end

  context "string option with :values attribute" do
    before(:each) { create :foo=>{:type=>:string, :values=>%w{angola abu abib}} }
    it "auto aliases if a match exists" do
      parse("-f", "an")[:foo].should == 'angola'
    end

    it "auto aliases first sorted match" do
      parse("-f", "a")[:foo].should == 'abib'
    end

    it "raises error if auto alias doesn't match" do
      assert_raises(OptionParser::Error) { parse("-f", "z") }
    end
  end
  
  context "string option" do
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
      assert_raises(OptionParser::Error) { parse("--foo", "--bar") }
    end

    it "raises error if not passed a value" do
      assert_raises(OptionParser::Error) { parse("--foo") }
    end

    it "overwrites earlier values with later values" do
      parse("--foo", "12", "--foo", "13")[:foo].should == "13"
    end
  end
  
  context " with one required and one string opt" do
    before :each do
      create "--foo" => :required, "--bar" => :string
    end
  
    it "raises an error if the required opt has no argument" do
      assert_raises(OptionParser::Error) { parse("--foo") }
    end
  
    it "raises an error if the required opt isn't given" do
      assert_raises(OptionParser::Error) { parse("--bar") }
    end
  
    it "raises an error if a opt name is given as the argument to the required opt" do
	  assert_raises(OptionParser::Error, "cannot pass opt '--bar' as an argument") { parse("--foo", "--bar") }
    end
  end
  
  it "extracts non-option arguments" do
    create "--foo" => :required, "--bar" => true
    parse("foo", "bar", "--baz", "--foo", "12", "--bar", "-T", "bang").should == {
      :foo => "12", :bar => true
    }
    @opt.leading_non_opts.should == ["foo", "bar", "--baz"]
    @opt.trailing_non_opts.should == ["-T", "bang"]
    @opt.non_opts.should == ["foo", "bar", "--baz", "-T", "bang"]
  end
  
  context "string arguments with default values" do
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
	  assert_raises(OptionParser::Error, "expected numeric value for '-n'; got \"foo\"") { parse("-n", "foo") }
    end
    
    it "raises error when opt is present without value" do
	    assert_raises(OptionParser::Error, "no value provided for option '-n'") { parse("-n") }
    end
  end

  context ":array type" do
    before(:each) { create :a=>:array, :b=>[1,2,3], :c=>{:type=>:array, :values=>%w{foo fa bar zebra}} }

    it "supports array defaults" do
      parse[:b].should == [1,2,3]
    end

    it "converts comma delimited values to an array" do
      parse("-a","1,2,5")[:a].should == %w{1 2 5}
    end

    it "raises error when option has no value" do
      assert_raises(OptionParser::Error) { parse("-a") }
    end

    it "auto aliases :values attribute" do
      parse("-c","f,b")[:c].should == %w{fa bar}
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
  end
end
end
