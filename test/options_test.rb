require File.join(File.dirname(__FILE__), 'test_helper')

context "Options" do
  def create(opts)
    @opt = Boson::OptionParser.new(opts)
  end
  
  def parse(*args)
    @non_opts = []
    @opt.parse(args.flatten)
  end

  context ":string type" do
    before {
      create "--foo" => :string, "--bar" => :string, :blah=>{:type=>:string, :default=>:huh}
    }

    it "doesn't set nonexistant options" do
      parse("--bling")[:bar].should == nil
    end

    it "sets values correctly" do
      parse("--foo", "12")[:foo].should == "12"
      parse("--bar", "12")[:bar].should == "12"
    end

    it "raises error if passed another valid option" do
      assert_error(Boson::OptionParser::Error, "cannot pass.*'foo'") { parse("--foo", "--bar") }
    end

    it "raises error if not passed a value" do
      assert_error(Boson::OptionParser::Error, "no value.*'foo'") { parse("--foo") }
    end

    it "overwrites earlier values with later values" do
      parse("--foo", "12", "--foo", "13")[:foo].should == "13"
    end

    it "can have symbolic default value" do
      parse('--blah','ok')[:blah].should == 'ok'
    end
  end

  context ":string type with :values attribute" do
    before_all { create :foo=>{:type=>:string, :values=>%w{angola abu abib}} }
    it "auto aliases if a match exists" do
      parse("-f", "an")[:foo].should == 'angola'
    end

    it "auto aliases first sorted match" do
      parse("-f", "a")[:foo].should == 'abib'
    end

    it "raises error if option doesn't auto alias or match given values" do
      assert_error(Boson::OptionParser::Error, "invalid.*'z'") { parse("-f", "z") }
    end

    it "doesn't raise error for a nonmatch if enum is false" do
      create :foo=>{:type=>:string, :values=>%w{angola abu abib}, :enum=>false}
      parse("-f", "z")[:foo].should == 'z'
    end
  end

  context ":string type with default value" do
    before { create "--branch" => "master" }
  
    it "should get the specified value" do
      parse("--branch", "bugfix").should == { :branch => "bugfix" }
    end

    it "should get the default value when not specified" do
      parse.should == { :branch => "master" }
    end
  end
  
  context ":numeric type" do
    before { create "n" => :numeric, "m" => 5 }
  
    it "supports numeric defaults" do
      parse["m"].should == 5
    end
  
    it "converts values to numeric types" do
      parse("-n", "3", "-m", ".5").should == {:n => 3, :m => 0.5}
    end
  
    it "raises error when value isn't numeric" do
	  assert_error(Boson::OptionParser::Error, "expected numeric value for.*'n'") { parse("-n", "foo") }
    end
  
    it "raises error when opt is present without value" do
	    assert_error(Boson::OptionParser::Error, "no value.*'n'") { parse("-n") }
    end
  end

  context ":array type" do
    before_all {
      create :a=>:array, :b=>[1,2,3], :c=>{:type=>:array, :values=>%w{foo fa bar zebra}, :enum=>false},
        :d=>{:type=>:array, :split=>" ", :values=>[:ab, :bc, :cd], :enum=>false},
        :e=>{:type=>:array, :values=>%w{some so silly}, :regexp=>true}
    }

    it "supports array defaults" do
      parse[:b].should == [1,2,3]
    end

    it "converts comma delimited values to an array" do
      parse("-a","1,2,5")[:a].should == %w{1 2 5}
    end

    it "raises error when option has no value" do
      assert_error(Boson::OptionParser::Error, "no value.*'a'") { parse("-a") }
    end

    it "auto aliases :values attribute" do
      parse("-c","f,b")[:c].should == %w{fa bar}
    end

    it "auto aliases symbolic :values" do
      parse("-d","a c")[:d].should == [:ab,:cd]
    end

    it "supports a configurable splitter" do
      parse("-d", "yogi berra")[:d].should == %w{yogi berra}
    end

    it "aliases * to all values" do
      parse("-c", '*')[:c].sort.should == %w{bar fa foo zebra}
      parse("-c", '*,ok')[:c].sort.should == %w{bar fa foo ok zebra}
    end

    it "aliases correctly with :regexp on" do
      parse("-e", 'so')[:e].sort.should == %w{so some}
    end
  end

  context ":hash type" do
    before_all {
      create :a=>:hash, :b=>{:default=>{:a=>'b'}}, :c=>{:type=>:hash, :keys=>%w{one two three}},
        :e=>{:type=>:hash, :keys=>[:one, :two, :three], :default_keys=>:three},
        :d=>{:type=>:hash, :split=>" "}
    }

    it "converts comma delimited pairs to hash" do
      parse("-a", "f:3,g:4")[:a].should == {'f'=>'3', 'g'=>'4'}
    end

    it "supports hash defaults" do
      parse[:b].should == {:a=>'b'}
    end

    it "raises error when option has no value" do
      assert_error(Boson::OptionParser::Error, "no value.*'a'") { parse("-a") }
    end

    it "raises error if invalid key-value pair given for unknown keys" do
      assert_error(Boson::OptionParser::Error, "invalid.*pair.*'a'") { parse("-a", 'b') }
    end

    it "auto aliases :keys attribute" do
      parse("-c","t:3,o:1")[:c].should == {'three'=>'3', 'one'=>'1'}
    end

    it "adds in explicit default keys with value only argument" do
      parse('-e', 'whoop')[:e].should == {:three=>'whoop'}
    end

    it "adds in default keys from known :keys with value only argument" do
      parse("-c","okay")[:c].should == {'one'=>'okay'}
    end

    it "auto aliases symbolic :keys" do
      parse("-e","t:3,o:1")[:e].should == {:three=>'3', :one=>'1'}
    end

    it "supports a configurable splitter" do
      parse("-d","a:ab b:bc")[:d].should == {'a'=>'ab', 'b'=>'bc'}
    end

    it "supports grouping keys" do
      parse("-c", "t,tw:foo,o:bar")[:c].should == {'three'=>'foo','two'=>'foo', 'one'=>'bar'}
    end

    it "aliases * to all keys" do
      parse("-c", "*:foo")[:c].should == {'three'=>'foo', 'two'=>'foo', 'one'=>'foo'}
      parse('-a', '*:foo')[:a].should == {'*'=>'foo'}
    end
  end
end