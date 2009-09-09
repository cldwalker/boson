module Boson::Commands::WebCore
  def self.config
    descriptions = {
      :install=>"Installs a library by url. Library should then be loaded with load_library.",
      :browser=>"Opens a url in a browser", :get=>"Gets the body of a url" }
    commands_hash = descriptions.inject({}) {|h,(k,v)| h[k.to_s] = {:description=>v}; h}
    {:library_file=>File.expand_path(__FILE__), :commands_hash=>commands_hash}
  end

  def get(url)
    %w{uri net/http}.each {|e| require e }
    Net::HTTP.get(URI.parse(url))
  rescue
    raise "Error opening #{url}"
  end

  def install(url, name=nil, force=false)
    name ||= strip_name_from_url(url)
    return "Please give a library name with this url." unless name
    filename = File.join Boson.repo.commands_dir, "#{name}.rb"
    return "Library name #{name} already exists. Try a different name." if File.exists?(filename) && !force
    File.open(filename, 'w') {|f| f.write get(url) }
    "Saved to #{filename}."
  end

  # non-mac users should override this with the launchy gem
  def browser(*urls)
    system('open', *urls)
  end

  private
  def strip_name_from_url(url)
    url[/\/([^\/.]+)(\.[a-z]+)?$/, 1]
  end
end