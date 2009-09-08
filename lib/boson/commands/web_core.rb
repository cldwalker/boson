module Boson::Commands::WebCore
  def self.config
    {:library_file=>File.expand_path(__FILE__) }
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

  def download(url)
    filename = determine_download_name(url)
    File.open(filename, 'w') { |f| f.write get(url) }
    filename
  end

  # non-mac users should override this with the launchy gem
  def browser(*urls)
    system('open', *urls)
  end

  private
  def strip_name_from_url(url)
    url[/\/([^\/.]+)(\.[a-z]+)?$/, 1]
  end

  def determine_download_name(url)
    FileUtils.mkdir_p(File.join(Boson.repo.dir,'downloads'))
    basename = strip_name_from_url(url) || url.sub(/^[a-z]+:\/\//,'').tr('/','-')
    filename = File.join(Boson.repo.dir, 'downloads', basename)
    filename += "-#{Time.now.strftime("%m_%d_%y_%H_%M_%S")}" if File.exists?(filename)
    filename
  end
end