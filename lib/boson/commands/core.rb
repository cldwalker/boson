module Boson::Commands::Core
  def self.config
    command_attributes = Boson::Command::ATTRIBUTES + [:usage, :full_name, :render_options]
    library_attributes = Boson::Library::ATTRIBUTES + [:library_type]

    commands = {
      'render'=>{:description=>"Render any object using Hirb"},
      'menu'=>{:description=>"Provide a menu to multi-select elements from a given array"},
      'usage'=>{:description=>"Print a command's usage", :options=>{:verbose=>:boolean}},
      'commands'=>{ :description=>"List or search commands",
        :options=>{:query_fields=>{:default=>['full_name'], :values=>command_attributes},
          :index=>{:type=>:boolean, :desc=>"Searches index"}},
        :render_options=>{:fields=>{:default=>[:full_name, :lib, :alias, :usage, :description], :values=>command_attributes} }
      },
      'libraries'=>{ :description=>"List or search libraries",
        :options=>{:query_fields=>{:default=>['name'], :values=>library_attributes},
          :index=>{:type=>:boolean, :desc=>"Searches index"} },
        :render_options=>{
          :fields=>{:default=>[:name, :commands, :gems, :library_type], :values=>library_attributes},
          :filters=>{:default=>{:gems=>[:join, ','],:commands=>:size}} }
      },
      'load_library'=>{:description=>"Load/reload a library", :options=>{:reload=>:boolean, :verbose=>true}}
    }

    {:library_file=>File.expand_path(__FILE__), :commands=>commands}
  end

  def commands(query='', options={})
    query_fields = options[:query_fields] || ['full_name']
    Boson::Index.read if options[:index]
    commands = options[:index] ? Boson::Index.commands : Boson.commands
    query_fields.map {|e| commands.select {|f| f.send(e).to_s =~ /#{query}/i } }.flatten
  end

  def libraries(query='', options={})
    Boson::Index.read if options[:index]
    libraries = options[:index] ? Boson::Index.libraries : Boson.libraries
    options[:query_fields].map {|e| libraries.select {|f| f.send(e).to_s =~ /#{query}/i } }.flatten
  end

  def load_library(library, options={})
    options[:reload] ? Boson::Library.reload_library(library, options) :
      Boson::Library.load_library(library, options)
  end

  def render(object, options={})
    Boson::View.render(object, options)
  end

  def menu(output, options={}, &block)
    Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
  end

  def usage(name, options={})
    msg = (command = Boson::Command.find(name)) ? "#{name} #{command.usage}" : "Command '#{name}' not found"
    puts msg
    if command && options[:verbose]
      if command.options && !command.options.empty?
        puts "\nCOMMAND OPTIONS"
        command.option_parser.print_usage_table
      end
      puts "\nGLOBAL/RENDER OPTIONS"
      Boson::Scientist.render_option_parser(command).print_usage_table
    end
  end
end