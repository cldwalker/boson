require 'yaml'
require 'hirb'
require 'alias'
$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'boson/manager'
require 'boson/loader'
require 'boson/library'
# order of library subclasses matters
require 'boson/libraries/module_library'
require 'boson/libraries/file_library'
require 'boson/libraries/gem_library'
require 'boson/command'
require 'boson/util'
require 'boson/commands/core'
require 'boson/commands/namespace'
require 'boson/searchable_array'

module Boson
  class <<self
    attr_accessor :dir, :main_object, :config
    alias_method :higgs, :main_object

    def libraries
      @libraries ||= SearchableArray.new
    end

    def commands
      @commands ||= SearchableArray.new
    end

    def dir
      @dir ||= File.expand_path(File.exists?('.boson') ? '.boson' : "#{ENV['HOME']}/.boson")
    end

    def main_object=(value)
      @main_object = value.extend(Commands)
    end

    # ==== Valid config keys:
    # [:libraries] Hash of libraries mapping their name to attribute hashes.
    # [:commands] Hash of commands mapping their name to attribute hashes.
    # [:defaults] Array of libraries to load at start up.
    # [:add_load_path] Boolean specifying whether to add a load path pointing to the lib under boson's directory. Defaults to false if
    #                  the lib directory isn't defined in the boson directory.
    def config(reload=false)
      if reload || @config.nil?
        @config = YAML::load_file(Boson.dir + '/boson.yml') rescue {:commands=>{}, :libraries=>{}}
      end
      @config
    end

    def activate(options={})
      Manager.activate(options)
    end

    def start(args=ARGV)
      if Boson::Manager.bin_init :discover=>args[0][/\w+/], :verbose=>true
        if args[0].include?('.')
          meth1, meth2 = args.shift.split('.', 2)
          dispatcher = main_object.send(meth1)
          args.unshift meth2
        else
          dispatcher = main_object
        end
        output = dispatcher.send(*args)
        puts Hirb::View.render_output(output) || output.inspect
      else
        $stderr.puts "Error: No command found to execute"
      end
    end
  end
end

Boson.main_object = self