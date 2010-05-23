require 'mocha'
require 'bacon'
require File.dirname(__FILE__)+'/bacon_extensions'
require 'mocha'
require 'mocha-on-bacon'
require 'boson'
Boson.constants.each {|e| Object.const_set(e, Boson.const_get(e)) unless Object.const_defined?(e) }

module TestHelpers
  # make local so it doesn't pick up my real boson dir
  Boson.repo.dir = File.dirname(__FILE__)
  # prevent extra File.exists? calls which interfere with stubs for it
  Boson.repo.config = {:libraries=>{}, :command_aliases=>{}, :console_defaults=>[]}
  Boson.instance_variable_set "@repos", [Boson.repo]

  def assert_error(error, message=nil)
    yield
  rescue error=>e
    e.class.should == error
    e.message.should =~ Regexp.new(message) if message
  else
    nil.should == error
  end

  def reset
    reset_main_object
    reset_boson
  end

  def reset_main_object
    Boson.send :remove_const, "Universe"
    eval "module ::Boson::Universe; include ::Boson::Commands::Namespace; end"
    Boson::Commands.send :remove_const, "Blah" if Boson::Commands.const_defined?("Blah")
    Boson.main_object = Object.new
  end

  def reset_boson
    reset_libraries
    Boson.instance_eval("@commands = nil")
  end

  def reset_libraries
    Boson.instance_eval("@libraries = nil")
  end

  def command_exists?(name, bool=true)
    (!!Boson::Command.find(name)).should == bool
  end

  def library_loaded?(name, bool=true)
    Boson::Manager.loaded?(name).should == bool
  end

  def library(name)
    Boson.library(name)
  end

  def library_has_module(lib, lib_module)
    Boson::Manager.loaded?(lib).should == true
    test_lib = library(lib)
    (test_lib.module.is_a?(Module) && (test_lib.module.to_s == lib_module)).should == true
  end

  def library_has_command(lib, command, bool=true)
    (lib = library(lib)) && lib.commands.include?(command).should == bool
  end

  # mocks as a file library
  def mock_library(lib, options={})
    options = {:file_string=>'', :exists=>true}.merge!(options)
    File.expects(:exists?).with(Boson::FileLibrary.library_file(lib.to_s, Boson.repo.dir)).
      at_least(1).returns(options.delete(:exists))
    File.expects(:read).returns(options.delete(:file_string))
  end

  def load(lib, options={})
    # prevent conflicts with existing File.read stubs
    Boson::MethodInspector.stubs(:inspector_in_file?).returns(false)
    mock_library(lib, options) unless options.delete(:no_mock)
    result = Boson::Manager.load([lib], options)
    Boson::FileLibrary.reset_file_cache
    result
  end

  def capture_stdout(&block)
    original_stdout = $stdout
    $stdout = fake = StringIO.new
    begin
      yield
    ensure
      $stdout = original_stdout
    end
    fake.string
  end

  def with_config(options)
    old_config = Boson.repo.config
    Boson.repo.config = Boson.repo.config.merge(options)
    yield
    Boson.repo.config = old_config
  end

  def capture_stderr(&block)
    original_stderr = $stderr
    $stderr = fake = StringIO.new
    begin
      yield
    ensure
      $stderr = original_stderr
    end
    fake.string
  end

  def create_library(libraries, attributes={})
    libraries = [libraries] unless libraries.is_a?(Array)
    libraries.map {|e|
      lib = Boson::Library.new({:name=>e}.update(attributes))
      Boson::Manager.add_library(lib); lib
    }
  end
end

class Bacon::Context
  include TestHelpers
  include BaconExtensions
  alias_method :context, :describe
  alias_method :test, :it
end

def context(*args, &block); describe(*args, &block); end