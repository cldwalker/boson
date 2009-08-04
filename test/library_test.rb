require File.join(File.dirname(__FILE__), 'test_helper')

module Boson
  class LibraryTest < Test::Unit::TestCase    
    def reset_libraries
      Boson.instance_eval("@libraries = SearchableArray.new")
    end

    context "load" do
      before(:each) { reset_libraries; Boson.config[:libraries] = {}}
      # test "loads and creates multiple basic libraries" do
      #   Loader.stubs(:load).returns(true)
      #   Loader.load(['blah'])
      #   Boson.libraries.find_by(:name=>'blah').size.should == 1
      #   Boson.libraries.find_by(:name=>'blah')[:loaded].should be(true)
      # end
      # adds lib: add or update
      # adds lib commands: only when loaded, lib except option, aliases (module + no module)
      # adds lib deps
    end

    def with_config(options)
      old_config = Boson.config
      Boson.config = Boson.config.merge(options)
      yield
      Boson.config = old_config
    end

    context "create" do
      before(:each) { reset_libraries }
      test "creates library" do
        Library.create(['blah'])
        Boson.libraries.find_by(:name=>'blah').is_a?(Library).should be(true)
      end

      test "creates library with config" do
        with_config(:libraries => {'blah'=>{:dependencies=>['bluh']}}) do
          Library.create(['blah'])
          Boson.libraries.find_by(:name=>'blah').is_a?(Library).should be(true)
          Boson.libraries.find_by(:name=>'blah')[:dependencies].should == ['bluh']
        end
      end

      # td :test merging
      test "merges multiple libraries with same name into one" do
        Library.create(['doh'])
        Library.create(['doh'])
        Boson.libraries.size.should == 1
      end
    end

    context "library_loaded" do
      before(:each) { reset_libraries }
      after(:each) { Boson.config[:libraries] = {}}

      test "returns false when library isn't loaded" do
        Boson.config[:libraries] = {'blah'=>{:loaded=>false}}
        Library.create(['blah'])
        Loader.library_loaded?('blah').should be(false)
      end

      test "returns true when library is loaded" do
        Boson.config[:libraries] = {'blah'=>{:loaded=>true}}
        Library.create(['blah'])
        Loader.library_loaded?('blah').should be(true)
      end
    end
  end
end
