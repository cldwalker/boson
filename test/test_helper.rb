require 'rubygems'
require 'test/unit'
require 'context' #gem install jeremymcanally-context --source http://gems.github.com
require 'matchy' #gem install jeremymcanally-matchy --source http://gems.github.com
require 'mocha'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'boson'

class Test::Unit::TestCase
  # make local so it doesn't pick up my real boson dir
  Boson.dir = File.expand_path('.')

  def reset_boson
    (Boson.instance_variables - ['@dir']).each do |e|
      Boson.instance_variable_set(e, nil)
    end
    Boson.send :remove_const, "Commands"
    eval "module ::Boson::Commands; end"
    $".delete('boson/commands/core.rb') && require('boson/commands/core.rb')
    $".delete('boson/commands/object_commands.rb') && require('boson/commands/object_commands.rb')
    Boson::Manager.instance_eval("@initialized = false")
  end

  def reset_main_object
    Boson.send :remove_const, "Commands"
    eval "module ::Boson::Commands; end"
    Boson.main_object = Object.new
  end

  def reset_libraries
    Boson.instance_eval("@libraries = nil")
  end

  def reset_commands
    Boson.instance_eval("@commands = nil")
  end

  def command_exists?(name, bool=true)
    Boson::Command.loaded?(name).should == bool
  end

  def library_loaded?(name, bool=true)
    Boson::Library.loaded?(name).should == bool
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
    old_config = Boson.config
    Boson.config = Boson.config.merge(options)
    yield
    Boson.config = old_config
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
end
