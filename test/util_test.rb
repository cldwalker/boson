require File.join(File.dirname(__FILE__), 'test_helper')

describe "Util" do
  it "underscore converts camelcase to underscore" do
    Util.underscore('Boson::MethodInspector').should == 'boson/method_inspector'
  end

  it "constantize converts string to class" do
    Util.constantize("Boson").should == ::Boson
  end

  describe "underscore_search" do
    def search(query, list)
      Util.underscore_search(query, list).sort {|a,b| a.to_s <=> b.to_s }
    end

    def first_search(query, list)
      Util.underscore_search(query, list, true)
    end

    it "matches non underscore strings" do
      search('som', %w{some words match sometimes}).should == %w{some sometimes}
    end

    it "matches first non underscore string" do
      first_search('wo', %w{some work wobbles}).should == 'work'
    end

    it "matches non underscore symbols" do
      search(:som, [:some, :words, :match, :sometimes]).should == [:some, :sometimes]
      search('som', [:some, :words, :match, :sometimes]).should == [:some, :sometimes]
    end

    it "matches underscore strings" do
      search('s_l', %w{some_long some_short some_lame}).should == %w{some_lame some_long}
    end

    it "matches first underscore string" do
      first_search('s_l', %w{some_long some_short some_lame}).should == 'some_long'
    end

    it "matches underscore symbols" do
      search(:s_l, [:some_long, :some_short, :some_lame]).should == [:some_lame, :some_long]
      search('s_l', [:some_long, :some_short, :some_lame]).should == [:some_lame, :some_long]
    end

    it "matches full underscore string" do
      search('some_long_name', %w{some_long_name some_short some_lame}).should == %w{some_long_name}
    end

    it "only matches exact match if multiple matches that start with exact match" do
      search('bl', %w{bl blang bling}).should == ['bl']
      first_search('bl', %w{bl blang bling}).should == 'bl'
    end
  end

  describe "tracer" do
    def sexp_from(string)
      Util::Tracer.process(@parser.parse(string), :mydef)
    end

    before do
      @parser = RubyParser.new
      @mydef  = "def mydef(a,*b)\n'my def!'\nend"
      @mdalt  = "def mydef(a,x)\n'my alt def!'\nend"
      @def2   = "def thisdef(a,b=1)\n'this def!'\nend"
      @def3   = "def thatdef(a,b=v)\n'that def!'\nend"
      @modb   = "module B\n#{@def2}\nend"
      @modc   = "module C\n#{@def3}\nend"
      exp = @parser.parse(@mydef)
      @mydef_sexp_w_trace = s(exp.shift, exp.shift, exp[0], Sexp.from_array(Util::Tracer::TM_BODY))
    end

    it "traces a single method on a module" do
      str = "module A\n#{@mydef}\nend"
      sexp_from(str).should == @mydef_sexp_w_trace
    end

    it "traces one method among other methods on a module" do
      str = "module A;#{@def2}\n#{@mydef}\n#{@def3}\nend"
      sexp_from(str).should == @mydef_sexp_w_trace
    end

    it "traces a method on a module with a class before the method" do
      str = "module A\nclass Z\n#{@def2}\nend\n#{@mydef}\nend"
      sexp_from(str).should == @mydef_sexp_w_trace
    end

    it "traces a method on a module with a class after the method" do
      str = "module A\n#{@mydef}\nclass Z\n#{@def2}\nend\nend"
      sexp_from(str).should == @mydef_sexp_w_trace
    end

    it "traces a method on one module of multiple modules" do
      str = "#{@modb}\nmodule A\n#{@mydef}\nend\n#{@modc}"
      sexp_from(str).should == @mydef_sexp_w_trace
    end

    it "can see the difference between two methods with the same name" do
      alt_sexp = sexp_from(@mdalt)
      alt_sexp.should.not == @mydef_sexp_w_trace
    end

    it "traces the last method with the same name" do
      str = "module N\n#{@mdalt}\nend\n#{@modb}\nmodule A\n#{@mydef}\nend\n#{@modc}"
      sexp_from(str).should == @mydef_sexp_w_trace
    end
  end
end
