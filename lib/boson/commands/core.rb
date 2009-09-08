module Boson::Commands; end # avoid having to :: prefix all classes
module Boson::Commands::Core
  def self.config
    {:library_file=>File.expand_path(__FILE__) }
  end

  def commands(query='', options={})
    options = {:fields=>[:name, :lib, :alias],:search_field=>:name}.merge(options)
    search_field = options.delete(:search_field)
    results = Boson.commands.select {|f| f.send(search_field) =~ /#{query}/ }
    render results, options
  end

  def libraries(query='', options={})
    options = {:fields=>[:name, :commands, :gems, :library_type], :search_field=>:name,
      :filters=>{:gems=>lambda {|e| e.join(',')},:commands=>:size}}.merge(options)
    search_field = options.delete(:search_field)
    results = Boson.libraries.select {|f| f.send(search_field) =~ /#{query}/ }
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
    Hirb::Console.render_output(object, options)
  end

  def menu(output, options={}, &block)
    Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
  end

  def usage(name, debug=false)
    help_string = get_help(name)
    (help_string !~ /^#{name}/ && !debug) ? "No help found for command #{name}." : help_string
  end

  private
  def get_usage(name)
    return "Command not loaded" unless (command = Boson.command(name.to_s) || Boson.command(name.to_s, :alias))
    return "Library for #{command_obj.name} not found" unless lib = Boson.library(command.lib)
    return "File for #{lib.name} library not found" unless File.exists?(lib.library_file || '')
    tabspace = "[ \t]"
    if match = /^#{tabspace}*def#{tabspace}+#{command.name}#{tabspace}*($|\(?\s*([^\)]+)\s*\)?\s*$)/.match(File.read(lib.library_file))
      "#{name} "+ (match.to_a[2] || '').split(/\s*,\s*/).map {|e| "[#{e}]"}.join(' ')
    else
      "Command not found in file"
    end
  end
end