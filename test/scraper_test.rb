require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class ScraperTest < Test::Unit::TestCase
    context "description_from_file" do
      before(:each) { 
        @lines = ["module Foo", "  # some comments yay", "  def foo", "  end", "end"]
      }
      def description(options={})
        Inspector.description_from_file(@lines.join("\n"), options[:line] || 3)
      end

      test "with description directly above returns it" do
        description.should == "some comments yay"
      end

      test "with explicit description returns it" do
        @lines[1] = '#@desc   some comments yay'
        description.should == "some comments yay"
      end

      test "with multi line description returns it" do
        @lines.delete_at(1)
        @lines.insert(1, '#@options :b=>1', '#@desc here be', '# comments')
        description(:line=>5).should == "here be comments"
      end

      test "with no description returns nil" do
        @lines[1] = ""
        description.should == nil
      end

      test "with options keyword returns nil" do
        @lines[1] = '#@options {:a=>1}'
        description.should == nil
      end

      test "with description not directly above returns nil" do
        @lines.insert(2, "   ")
        description(:line=>4).should == nil
      end
    end

    context "options_from_file" do
      before(:all) { eval "module Optional; def self.bling; {:a=>'bling'}; end; end" }
      before(:each) {
        @lines = ["module Foo", '  #@options {:a=>true}', "  def foo", "  end", "end"]
      }
      def options(opts={})
        @lines[1] = opts[:value] if opts[:value]
        args = [@lines.join("\n"), 3, Optional]
        args.pop if opts[:no_module]
        Inspector.options_from_file(*args)
      end

      test "with no module and options detects options" do
        options(:no_module=>true).should == true
      end

      test "with no module and no options doesn't detect options" do
        options(:no_module=>true, :value=>"# no options").should == nil
      end

      context "with module" do
        test "and options returns options" do
          options.should == {:a=>true}
        end

        test "and hash-like options returns hashified options" do
          options(:value=>'#@options :a => 2').should == {:a=>2}
        end

        test "and whitespaced options returns options" do
          options(:value=>"\t"+ '#    @options {:a=>1}').should == {:a=>1}
        end

        test "and local value options returns options" do
          options(:value=>'#@options bling').should == {:a=>'bling'}
        end

        test "and multi line options returns options" do
          @lines.delete_at(1)
          @lines.insert(1, '#@options {:a =>', " # 1}", "# some comments")
          Inspector.options_from_file(@lines.join("\n"), 5, Optional).should == {:a=>1}
        end

        test "and failed eval returns nil" do
          options(:value=>'#@options !--').should == nil
        end

        test "and no options returns nil" do
          options(:value=>"# nada").should == nil
        end
      end
    end
  end
end