module Boson::Commands::WebCore
  def get(url)
    require 'net/http'
    ::Net::HTTP.get(::URI.parse(url))
  end

  def download(url)
    filename = determine_download_name(url)
    ::File.open(filename, 'w') { |f| f.write get(url) }
    filename
  end

  # non-mac users should override this with the launchy gem
  def browser(*urls)
    system('open', *urls)
  end

  private
  def determine_download_name(url)
    require 'uri'
    ::FileUtils.mkdir_p(::File.join(::Boson.dir,'downloads'))

    basename = ::URI.parse(url).path.split('/')[-1]
    basename = ::URI.parse(url).host.sub('www.','') if basename.nil? || basename.empty?
    filename = ::File.join(::Boson.dir, 'downloads', basename)
    filename += "-#{::Time.now.strftime("%m_%d_%y_%H_%M_%S")}" if ::File.exists?(filename)
    filename
  end
end