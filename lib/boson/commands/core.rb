module Boson::Commands::Core
  def self.config
    descriptions = {
      :commands=>"List or search loaded commands",
      :libraries=>"List or search loaded libraries",
      :unloaded_libraries=>"List libraries that haven't been loaded yet",
      :load_library=>"Load a library", :reload_library=>"Reload a library",
      :index=>"Generate index of all libraries and commands",
      :render=>"Render any object using Hirb",
      :menu=>"Provide a menu to multi-select elements from a given array",
      :usage=>"Print a command's usage"
    }
    commands = descriptions.inject({}) {|h,(k,v)| h[k.to_s] = {:description=>v}; h}
    command_attributes = Boson::Command::ATTRIBUTES + [:usage]
    commands['commands'][:options] = {:query_field=>{:default=>'name', :values=>command_attributes}, :index=>:boolean}
    commands['commands'][:render_options] = {
      :fields=>{:default=>[:name, :lib, :alias, :usage, :description], :values=>command_attributes} }
    library_attributes = Boson::Library::ATTRIBUTES + [:library_type]
    commands['libraries'][:options] = {:query_field=>{:default=>'name', :values=>library_attributes}, :index=>:boolean}
    commands['libraries'][:render_options] = {
      :fields=>{:default=>[:name, :commands, :gems, :library_type], :values=>library_attributes},
      :filters=>{:default=>{:gems=>lambda {|e| e.join(',')},:commands=>:size}} }
    {:library_file=>File.expand_path(__FILE__), :commands=>commands}
  end

  def commands(query='', options={})
    query_field = options.delete(:query_field)
    Boson::Index.read if options[:index]
    commands = options[:index] ? Boson::Index.commands : Boson.commands
    commands.select {|f| f.send(query_field).to_s =~ /#{query}/i }
  end

  def libraries(query='', options={})
    query_field = options.delete(:query_field)
    Boson::Index.read if options[:index]
    libraries = options[:index] ? Boson::Index.libraries : Boson.libraries
    libraries.select {|f| f.send(query_field).to_s =~ /#{query}/i }
  end

  def unloaded_libraries
    (Boson::Runner.all_libraries - Boson.libraries.map {|e| e.name }).sort
  end

  def load_library(library, options={})
    Boson::Library.load_library(library, {:verbose=>true}.merge!(options))
  end

  def reload_library(name, options={})
    Boson::Library.reload_library(name, {:verbose=>true}.merge!(options))
  end

  def render(object, options={})
    options[:class] = options.delete(:as) || :auto_table
    if object.is_a?(Array) && (sort = options.delete(:sort)) && sort = sort.to_s
      begin
        sort_lambda = object[0].is_a?(Hash) ? (object[0][sort].respond_to?(:<=>) ?
          lambda {|e| e[sort] } : lambda {|e| e[sort].to_s }) :
          (object[0].send(sort).respond_to?(:<=>) ? lambda {|e| e.send(sort)} :
          lambda {|e| e.send(sort).to_s })
        object = object.sort_by &sort_lambda
        object = object.reverse if options[:reverse_sort]
      rescue NoMethodError, ArgumentError
        $stderr.puts "Sort failed with nonexistant method '#{sort}'"
      end
    end
    Hirb::Console.render_output(object, options)
  end

  def menu(output, options={}, &block)
    Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
  end

  def usage(name)
    (command = Boson::Command.find(name)) ? "#{name} #{command.usage}" : "Command '#{name}' not found"
  end
end