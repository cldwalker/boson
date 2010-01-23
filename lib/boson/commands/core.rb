module Boson::Commands::Core #:nodoc:
  extend self

  def config
    command_attributes = Boson::Command::ATTRIBUTES + [:usage, :full_name, :render_options]
    library_attributes = Boson::Library::ATTRIBUTES + [:library_type]

    commands = {
      'render'=>{:desc=>"Render any object using Hirb"},
      'menu'=>{:desc=>"Provide a menu to multi-select elements from a given array"},
      'usage'=>{:desc=>"Print a command's usage", :options=>{[:verbose, :V]=>:boolean}},
      'commands'=>{
        :desc=>"List or search commands. Query must come before any options.", :default_option=>'query',
        :options=>{ :index=>{:type=>:boolean, :desc=>"Searches index"},
          :local=>{:type=>:boolean, :desc=>"Local commands only" } },
        :render_options=>{
          :headers=>{:default=>{:desc=>'description'}},
          :query=>{:keys=>command_attributes, :default_keys=>'full_name'},
          :fields=>{:default=>[:full_name, :lib, :alias, :usage, :desc], :values=>command_attributes, :enum=>false},
          :filters=>{:default=>{:render_options=>:inspect, :options=>:inspect, :args=>:inspect, :config=>:inspect}}
        }
      },
      'libraries'=>{
        :desc=>"List or search libraries. Query must come before any options.", :default_option=>'query',
        :options=>{ :index=>{:type=>:boolean, :desc=>"Searches index"},
          :local=>{:type=>:boolean, :desc=>"Local libraries only" } },
        :render_options=>{
          :query=>{:keys=>library_attributes, :default_keys=>'name'},
          :fields=>{:default=>[:name, :commands, :gems, :library_type], :values=>library_attributes, :enum=>false},
          :filters=>{:default=>{:gems=>[:join, ','],:commands=>:size}, :desc=>"Filters to apply to library fields" }}
      },
      'load_library'=>{:desc=>"Load a library", :options=>{[:verbose,:V]=>true}}
    }

    {:namespace=>false, :library_file=>File.expand_path(__FILE__), :commands=>commands}
  end

  def commands(options={})
    cmds = options[:index] ? (Boson::Index.read || true) && Boson::Index.commands : Boson.commands
    options[:local] ? cmds.select {|e| e.library && e.library.local? } : cmds
  end

  def libraries(options={})
    libs = options[:index] ? (Boson::Index.read || true) && Boson::Index.libraries : Boson.libraries
    options[:local] ? libs.select {|e| e.local? } : libs
  end

  def load_library(library, options={})
    Boson::Manager.load(library, options)
  end

  def render(object, options={})
    Boson::View.render(object, options)
  end

  def menu(output, options={}, &block)
    Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
  end

  def usage(command, options={})
    msg = (cmd = Boson::Command.find(command)) ? "#{command} #{cmd.usage}" : "Command '#{cmd}' not found"
    puts msg
    if cmd && options[:verbose]
      if cmd.options && !cmd.options.empty?
        puts "\nLOCAL OPTIONS"
        cmd.option_parser.print_usage_table
      end
      puts "\nGLOBAL OPTIONS"
      Boson::Scientist.option_command(cmd).option_parser.print_usage_table
    end
  end
end