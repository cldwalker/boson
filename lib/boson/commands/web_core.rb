module Boson::Commands::WebCore #:nodoc:
  def self.config
    descriptions = {
      :install=>"Installs a library by url. Library should then be loaded with load_library.",
      :browser=>"Opens urls in a browser on a Mac", :get=>"Gets the body of a url" }
    commands = descriptions.inject({}) {|h,(k,v)| h[k.to_s] = {:description=>v}; h}
    commands['install'][:options] = {:name=>{:type=>:string, :desc=>"Library name to save to"},
      :force=>{:type=>:boolean, :desc=>'Overwrites an existing library'},
      :module_wrap=>{:type=>:boolean, :desc=>"Wraps a module around install using library name"},
      :method_wrap=>{:type=>:boolean, :desc=>"Wraps a method and module around installe library using library name"}}
    {:library_file=>File.expand_path(__FILE__), :commands=>commands}
  end

  def get(url)
    %w{uri net/http}.each {|e| require e }
    Net::HTTP.get(URI.parse(url))
  rescue
    raise "Error opening #{url}"
  end

  def install(url, options={})
    options[:name] ||= strip_name_from_url(url)
    return puts("Please give a library name for this url.") if options[:name].empty?
    filename = File.join Boson.repo.commands_dir, "#{options[:name]}.rb"
    return puts("Library name #{options[:name]} already exists. Try a different name.") if File.exists?(filename) && !options[:force]
    File.open(filename, 'w') {|f| f.write get(url) }

    if options[:method_wrap] || options[:module_wrap]
      file_string = File.read(filename)
      file_string = "def #{options[:name]}\n#{file_string}\nend" if options[:method_wrap]
      unless (mod_name = Boson::Util.camelize(options[:name]))
        return puts("Can't wrap install with name #{options[:name]}")
      end
      file_string = "module #{mod_name}\n#{file_string}\nend"
      File.open(filename, 'w') {|f| f.write file_string }
    end
    puts "Saved to #{filename}."
  end

  # non-mac users should override this with the launchy gem
  def browser(*urls)
    system('open', *urls)
  end

  private
  def strip_name_from_url(url)
    url[/\/([^\/.]+)(\.[a-z]+)?$/, 1].to_s.gsub('-', '_').gsub(/[^a-zA-Z_]/, '')
  end
end