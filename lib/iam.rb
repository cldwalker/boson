require 'yaml'
require 'hirb'
require 'alias'
$:.unshift File.dirname(__FILE__) unless $:.include? File.expand_path(File.dirname(__FILE__))
require 'iam/config'
require 'iam/manager'
require 'iam/library'
require 'iam/util'
require 'iam/commands'

module Iam
  module Libraries; end
  class <<self
    extend Config
    attr_reader :base_dir, :libraries, :base_object, :commands
    def init(options={})
      @libraries ||= []
      @commands ||= []
      @base_dir = options[:base_dir] || (File.exists?("#{ENV['HOME']}/.irb") ? "#{ENV['HOME']}/.irb" : '.irb')
      $:.unshift @base_dir unless $:.include? File.expand_path(@base_dir)
      load File.join(@base_dir, 'libraries.rb') if File.exists?(File.join(@base_dir, 'libraries.rb'))
    end

    # can only be run once b/c of alias and extend
    def register(*args)
      options = args[-1].is_a?(Hash) ? args.pop : {}
      init(options)
      @base_object = options[:with] || @base_object || Object.new
      @base_object.send :extend, Iam::Libraries
      Iam::Manager.create_libraries(args, options)
      Iam::Manager.create_aliases
    end
  end  
end
__END__
def create_commands(name, options={})
  if options[:type] == :gem
    require name
    (options[:methods] || []).map {|e|
      create_command(:name=>e)
    }
  else
    name.instance_methods.map {|e|
      create_command(:name=>e)
    }
  end
end

def create_command(command)
  {:name=>command[:name], :description=>(config['commands'][command[:name]]['description'] rescue nil)}
end

#def search(query='')
  #print_commands Iam.commands.select {|e| e[:name] =~ /#{query}/}
#end

#def print_commands(commands)
  #puts Hirb::Helpers::Table.render(commands, :fields=>[:name, :description])
#end