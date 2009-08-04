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
    Boson.send :remove_const, "Libraries"
    eval "module ::Boson::Libraries; end"
    $".delete('boson/libraries/core.rb') && require('boson/libraries/core.rb')
    $".delete('boson/libraries/object_commands.rb') && require('boson/libraries/object_commands.rb')
    Boson::Manager.instance_eval("@initialized = false")
  end
end
