require File.join(File.dirname(__FILE__), 'test_helper')
require 'boson/bin_runner'
BinRunner = Boson::BinRunner

describe "BinRunner" do
  def aborts_with(regex)
    BinRunner.expects(:abort).with {|e| e[regex] }
    yield
  end

  unless ENV['FAST']
    it "prints usage with no arguments" do
      boson
      stdout.should =~ /^boson/
    end

    it "prints usage with --help" do
      %w{-h --help}.each do |option|
        boson option
        stdout.should =~ /^boson/
      end
    end

    it 'prints version with --version' do
      boson '--version'
      stdout.chomp.should == "boson #{Boson::VERSION}"
    end

    it "executes string with --execute" do
      %w{--execute -e}.each do |option|
        boson "#{option} 'print 1 + 1'"
        stdout.should == '2'
      end
    end

    it "sets $DEBUG with --ruby-debug" do
      %w{--ruby_debug -D}.each do |option|
        boson "#{option} -e 'print $DEBUG'"
        stdout.should == 'true'
      end
    end

    it "sets Boson.debug with --debug" do
      boson "--debug -e 'print Boson.debug'"
      stdout.should == 'true'
    end

    it "prepends to $: with --load_path" do
      %w{--load_path -I}.each do |option|
        boson "#{option}=lib -e 'print $:[0]'"
        stdout.should == 'lib'
      end
    end

    it "prints error for unexpected error" do
      boson %[-e 'raise "blarg"']
      stderr.chomp.should == "Error: blarg"
    end

    it "prints error for too many arguments" do
      with_command('dude') do
        boson "dude 1 2 3"
        stderr.should =~ /^'dude' was called incorrectly/
        process.success?.should == false
      end
    end

    it "prints error for invalid command" do
      boson 'blarg'
      stderr.chomp.should == %[Could not find command "blarg"]
      process.success?.should == false
    end
  end

  it ".parse_args only translates options before command" do
    BinRunner.send(:parse_args, ['-d', 'com', '-v']).should == ["com", {debug: true}, ['-v']]
    BinRunner.send(:parse_args, ['com', '-v']).should == ["com", {}, ['-v']]
  end
end
