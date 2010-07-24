require File.join(File.dirname(__FILE__), 'test_helper')

describe "CommentInspector" do
  before_all { eval "module ::Optional; def self.bling; {:a=>'bling'}; end; end" }
  describe "scrapes description" do
    before { 
      @lines = ["module Foo", "  # some comments yay", "  def foo", "  end", "end"]
    }
    def description(options={})
      CommentInspector.scrape(@lines.join("\n"), options[:line] || 3, Optional)[:desc]
    end

    it "directly above method returns desc" do
      description.should == "some comments yay"
    end

    it "with explicit @desc returns desc" do
      @lines[1] = '#@desc   some comments yay'
      description.should == "some comments yay"
    end

    it "of multiple lines returns desc" do
      @lines.delete_at(1)
      @lines.insert(1, '#@options :b=>1', '#@desc here be', '# comments')
      description(:line=>5).should == "here be comments"
    end

    it "that is empty returns nil" do
      @lines[1] = ""
      description.should == nil
    end

    it "that is empty with options keyword returns nil" do
      @lines[1] = '#@options {:a=>1}'
      description.should == nil
    end

    it "not directly above returns nil" do
      @lines.insert(2, "   ")
      description(:line=>4).should == nil
    end
  end

  describe "scrapes options" do
    before {
      @lines = ["module Foo", '  #@options {:a=>true}', "  def foo", "  end", "end"]
    }
    def options(opts={})
      @lines[1] = opts[:value] if opts[:value]
      args = [@lines.join("\n"), opts[:line] || 3, Optional]
      CommentInspector.scrape(*args)[:options]
    end

    it "that are basic" do
      options.should == {:a=>true}
    end

    it "that are hash-like" do
      options(:value=>'#@options :a => 2').should == {:a=>2}
    end

    it "that are whitespaced" do
      options(:value=>"\t"+ '#    @options {:a=>1}').should == {:a=>1}
    end

    it "that have a local value" do
      options(:value=>'#@options bling').should == {:a=>'bling'}
    end

    it "that are multi-line" do
      @lines.delete_at(1)
      @lines.insert(1, '#@options {:a =>', " # 1}", "# some comments")
      options(:line=>5).should == {:a=>1}
    end

    it "with failed eval and returns nil" do
      options(:value=>'#@options !--').should == nil
    end

    it "that are empty and returns nil" do
      options(:value=>"# nada").should == nil
    end

    it "when @option overwrites @options" do
      @lines.insert(1, '  #@option :a, :boolean')
      options(:line=>4).should == {:a=>:boolean}
    end

    it "when set by @option and @options" do
      @lines.insert(1, '  #@option :b, :boolean')
      options(:line=>4).should == {:b=>:boolean, :a=>true}
    end

    it "when set by @option" do
      @lines.delete_at(1)
      @lines.insert(1, ' #@option :b, :string', '  #@option :a, 4')
      options(:line=>4).should == {:b=>:string, :a=>4}
    end

    it "when set by multi-line @option" do
      @lines.delete_at(1)
      @lines.insert(1, ' #@option :b, :type=>:string,', '  # :values=>%w{one two}', '# some comments')
      options(:line=>5).should == {:b=>{:type=>:string, :values=>%w{one two}}}
    end

    it "and ignores invalid @option's" do
      @lines.delete_at(1)
      @lines.insert(1, '  #@option :b=>:string', '  #@option :a, :string')
      options(:line=>4).should == {:a=>:string}
    end
  end

  it "scrapes all comment types with implicit desc" do
    @lines = ["module Foo", '# @config :a=>true', '# @render_options :b=>1', '  # @options {:a=>true}',
      '#blah', "  def foo", "  end", "end"]
    expected = {:desc=>"blah", :options=>{:a=>true}, :render_options=>{:b=>1}, :config=>{:a=>true}}
    CommentInspector.scrape(@lines.join("\n"), 6, Optional).should == expected
  end

  it "scrapes all comment types with explicit desc" do
    @lines = ["module Foo",  '#@desc blah', '# @render_options :b=>1,', '# :c=>2',
      '  # @options {:a=>true}', '  # @config :a=>true', "  def foo", "  end", "end"]
    expected = {:desc=>"blah", :options=>{:a=>true}, :render_options=>{:b=>1, :c=>2}, :config=>{:a=>true}}
    CommentInspector.scrape(@lines.join("\n"), 7, Optional).should == expected
  end
end