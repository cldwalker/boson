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
    commands['commands'][:options] = {:query_field=>{:default=>'name', :values=>command_attributes},
      :sort=>{:type=>:string, :values=>command_attributes}, :reverse_sort=>:boolean, :index=>:boolean,
      :fields=>{:default=>[:name, :lib, :alias, :usage, :description], :values=>command_attributes} }
    library_attributes = Boson::Library::ATTRIBUTES + [:library_type]
    commands['libraries'][:options] = {:query_field=>{:default=>'name', :values=>library_attributes},
      :sort=>{:type=>:string, :values=>library_attributes}, :reverse_sort=>:boolean, :index=>:boolean,
      :fields=>{:default=>[:name, :commands, :gems, :library_type], :values=>library_attributes} }
    {:library_file=>File.expand_path(__FILE__), :commands=>commands}
  end

  def commands(query='', options={})
    query_field = options.delete(:query_field)
    Boson::Index.read if options[:index]
    commands = options[:index] ? Boson::Index.commands : Boson.commands
    results = commands.select {|f| f.send(query_field).to_s =~ /#{query}/i }
    render results, options
  end

  def libraries(query='', options={})
    options = {:filters=>{:gems=>lambda {|e| e.join(',')},:commands=>:size}}.merge(options)
    query_field = options.delete(:query_field)
    Boson::Index.read if options[:index]
    libraries = options[:index] ? Boson::Index.libraries : Boson.libraries
    results = libraries.select {|f| f.send(query_field).to_s =~ /#{query}/i }
    render results, options
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
        object = object.sort_by {|e| e.send(sort).to_s }
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
    (command = Boson.command(name.to_s) || Boson.command(name.to_s, :alias)) ?
      "#{name} #{command.usage}" : "Command '#{name}' not found"
  end

  private
end