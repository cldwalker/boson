require File.join(File.dirname(__FILE__), 'test_helper')

describe "CommentInspector" do
  before_all { eval "module Optional; def self.bling; {:a=>'bling'}; end; end" }
  describe "scrapes description" do
    before { 
      @lines = ["module Foo", "  # some comments yay", "  def foo", "  end", "end"]
    }
    def description(options={})
      CommentInspector.scrape(@lines.join("\n"), options[:line] || 3, Optional)[:desc]
    end

    test "directly above method returns desc" do
      description.should == "some comments yay"
    end

    test "with explicit @desc returns desc" do
      @lines[1] = '#@desc   some comments yay'
      description.should == "some comments yay"
    end

    test "of multiple lines returns desc" do
      @lines.delete_at(1)
      @lines.insert(1, '#@options :b=>1', '#@desc here be', '# comments')
      description(:line=>5).should == "here be comments"
    end

    test "that is empty returns nil" do
      @lines[1] = ""
      description.should == nil
    end

    test "that is empty with options keyword returns nil" do
      @lines[1] = '#@options {:a=>1}'
      description.should == nil
    end

    test "not directly above returns nil" do
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
      args = [@lines.join("\n"), 3, Optional]
      CommentInspector.scrape(*args)[:options]
    end

    test "that are basic return options" do
      options.should == {:a=>true}
    end

    test "that are hash-like returns hashified options" do
      options(:value=>'#@options :a => 2').should == {:a=>2}
    end

    test "that are whitespaced return options" do
      options(:value=>"\t"+ '#    @options {:a=>1}').should == {:a=>1}
    end

    test "that have a local value return options" do
      options(:value=>'#@options bling').should == {:a=>'bling'}
    end

    test "that are multi-line return options" do
      @lines.delete_at(1)
      @lines.insert(1, '#@options {:a =>', " # 1}", "# some comments")
      CommentInspector.scrape(@lines.join("\n"), 5, Optional)[:options].should == {:a=>1}
    end

    test "with failed eval return nil" do
      options(:value=>'#@options !--').should == nil
    end

    test "that are empty return nil" do
      options(:value=>"# nada").should == nil
    end
  end

  test "scrapes all comment types with implicit desc" do
    @lines = ["module Foo", '# @config :a=>true', '# @render_options :b=>1', '  # @options {:a=>true}',
      '#blah', "  def foo", "  end", "end"]
    expected = {:desc=>"blah", :options=>{:a=>true}, :render_options=>{:b=>1}, :config=>{:a=>true}}
    CommentInspector.scrape(@lines.join("\n"), 6, Optional).should == expected
  end

  test "scrapes all comment types with explicit desc" do
    @lines = ["module Foo",  '#@desc blah', '# @render_options :b=>1,', '# :c=>2',
      '  # @options {:a=>true}', '  # @config :a=>true', "  def foo", "  end", "end"]
    expected = {:desc=>"blah", :options=>{:a=>true}, :render_options=>{:b=>1, :c=>2}, :config=>{:a=>true}}
    CommentInspector.scrape(@lines.join("\n"), 7, Optional).should == expected
  end
end