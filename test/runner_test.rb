require File.join(File.dirname(__FILE__), 'test_helper')

describe "repl_runner" do
  def start(hash={})
    Hirb.stubs(:enable)
    Boson.start(hash.merge(:verbose=>false))
  end

  before_all { reset }
  before { ConsoleRunner.instance_eval("@initialized = false") }

  test "loads default libraries and libraries in :console_defaults config" do
    defaults = Runner.default_libraries + ['yo']
    with_config(:console_defaults=>['yo']) do
      Manager.expects(:load).with {|*args| args[0] == defaults }
      start
    end
  end

  test "doesn't call init twice" do
    capture_stderr { start }
    ConsoleRunner.expects(:init).never
    start
  end

  test "loads multiple libraries with :libraries option" do
    ConsoleRunner.expects(:init)
    Manager.expects(:load).with([:lib1,:lib2], anything)
    start(:libraries=>[:lib1, :lib2])
  end

  test "autoloader autoloads libraries" do
    start(:autoload_libraries=>true)
    Index.expects(:read)
    Index.expects(:find_library).with('blah').returns('blah')
    Manager.expects(:load).with('blah', anything)
    Boson.main_object.blah
  end
  after_all { FileUtils.rm_r File.dirname(__FILE__)+'/config' if File.exists? File.dirname(__FILE__)+'/config' }
end