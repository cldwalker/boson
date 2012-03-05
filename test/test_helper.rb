require 'mocha'
require 'boson'
require 'fileutils'
require 'boson/runner'
require 'bahia'

ENV['RSPEC'] = '1' if $0[/rspec/]
unless ENV['RSPEC']
  require 'bacon'
  require 'bacon/bits'
  require 'mocha-on-bacon'
end

Object.send :remove_const, :OptionParser
Boson.constants.each {|e| Object.const_set(e, Boson.const_get(e)) unless Object.const_defined?(e) }
ENV['BOSONRC'] = File.dirname(__FILE__) + '/.bosonrc'

module TestHelpers
  ## Misc
  def assert_error(error, message=nil)
    yield
  rescue error=>e
    e.class.should == error
    e.message.should =~ Regexp.new(message) if message
  else
    nil.should == error
  end

  def remove_constant(name, mod=Object)
    mod.send(:remove_const, name) if mod.const_defined?(name, false)
  end

  def with_config(options)
    old_config = Boson.config
    Boson.config = Boson.config.merge(options)
    yield
    Boson.config = old_config
  end

  def manager_load(lib, options={})
    @stderr = capture_stderr { Manager.load(lib, options) }
  end

  def stderr
    @stderr.chomp
  end

  ## Reset
  def reset
    reset_main_object
    reset_boson
  end

  def reset_main_object
    Boson.send :remove_const, "Universe"
    eval "module ::Boson::Universe; end"
    remove_constant "Blah", Boson::Commands
    Boson.main_object = Object.new
  end

  def reset_boson
    reset_libraries
    Boson.instance_eval("@commands = nil")
  end

  def reset_libraries
    Boson.instance_eval("@libraries = nil")
  end

  ## Library
  def library_loaded?(name, bool=true)
    Manager.loaded?(name).should == bool
  end

  def library(name)
    Boson.library(name)
  end

  def library_has_command(lib, command, bool=true)
    (lib = library(lib)) && lib.commands.include?(command).should == bool
  end

  ## Factories
  def create_runner(*methods, &block)
    options = methods[-1].is_a?(Hash) ? methods.pop : {}
    library = options[:library] || :Blarg
    remove_constant library

    Object.const_set(library, Class.new(Boson::Runner)).tap do |klass|
      if block
        klass.module_eval(&block)
      else
        methods.each do |meth|
          klass.send(:define_method, meth) { }
        end
      end
    end
  end

  def create_library(hash)
    Library.new(hash).tap {|lib| Manager.add_library lib }
  end

  def create_command(hash)
    Command.new(hash).tap {|cmd| Boson.commands << cmd }
  end

  ## Capture
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

  if ENV['RSPEC']
    def should_not_raise(&block)
      block.should_not raise_error
    end
  else
    # Since rspec doesn't allow should != or should.not
    Object.send(:define_method, :should_not) {|*args, &block|
      should.not(*args, &block)
    }
    def should_not_raise(&block)
      should.not.raise &block
    end
  end
end

if ENV['RSPEC']
  module RspecBits
    def before_all(&block)
      before(:all, &block)
    end

    def after_all(&block)
      after(:all, &block)
    end
  end

  RSpec.configure {|c|
    c.mock_with :mocha
    c.extend RspecBits
    c.include TestHelpers, Bahia
  }
else
  Bacon::Context.send :include, Bahia
  Bacon::Context.send :include, TestHelpers
end
