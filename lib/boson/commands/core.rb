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
    commands['commands'][:options] = {:field=>:optional, :sort=>:optional}
    commands['libraries'][:options] = {:field=>:optional, :sort=>:optional}
    {:library_file=>File.expand_path(__FILE__), :commands=>commands}
  end

  def commands(*args)
    query = args[0].is_a?(String) ? args.shift : ''
    options = {:fields=>[:name, :lib, :alias, :option_help],:field=>:name}.merge(args[0] || {})
    search_field = options.delete(:field)
    results = Boson.commands.select {|f| f.send(search_field).to_s =~ /#{query}/i }
    options[:fields] << :description if results.any? {|e| ! e.description.nil?}
    render results, options
  end

  def libraries(*args)
    query = args[0].is_a?(String) ? args.shift : ''
    options = {:fields=>[:name, :commands, :gems, :library_type], :field=>:name,
      :filters=>{:gems=>lambda {|e| e.join(',')},:commands=>:size}}.merge(args[0] || {})
    search_field = options.delete(:field)
    results = Boson.libraries.select {|f| f.send(search_field).to_s =~ /#{query}/i }
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

  def index
    Boson::Runner.index_commands
    puts "Indexed #{Boson.libraries.size} libraries and #{Boson.commands.size} commands."
  end

  def render(object, options={})
    options[:class] = options.delete(:as) || :auto_table
    if object.is_a?(Array) && (sort = options.delete(:sort))
      begin
        object = object.sort_by {|e| e.send(sort).to_s }
      rescue NoMethodError
        $stderr.puts "Sort failed with nonexistant method '#{sort}'"
      end
    end
    Hirb::Console.render_output(object, options)
  end

  def menu(output, options={}, &block)
    Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
  end

  def usage(name, debug=false)
    help_string = Boson::Inspector.command_usage(name)
    (help_string !~ /^#{name}/ && !debug) ? "No help found for command #{name}." : help_string
  end

  private
end