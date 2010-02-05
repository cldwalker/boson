module Boson::Commands::WebCore
  extend self

  def config #:nodoc:
    descriptions = {
      :install=>"Installs a library by url. Library should then be loaded with load_library.",
      :browser=>"Opens urls in a browser on a Mac", :get=>"Gets the body of a url", :post=>'Posts to url',
      :build_url=>"Builds a url, escaping the given params"
    }
    commands = descriptions.inject({}) {|h,(k,v)| h[k.to_s] = {:desc=>v}; h}
    commands['install'][:options] = {:name=>{:type=>:string, :desc=>"Library name to save to"},
      :force=>{:type=>:boolean, :desc=>'Overwrites an existing library'},
      :module_wrap=>{:type=>:boolean, :desc=>"Wraps a module around install using library name"},
      :method_wrap=>{:type=>:boolean, :desc=>"Wraps a method and module around installed library using library name"}}
    commands['install'][:args] = [['url'],['options', {}]]
    {:library_file=>File.expand_path(__FILE__), :commands=>commands, :namespace=>false}
  end

  # Requires libraries only once before defining method with given block
  def self.def_which_requires(meth, *libs, &block)
    define_method(meth) do |*args|
      libs.each {|e| require e }
      define_method(meth, block).call(*args)
    end
  end

  def_which_requires(:get, 'uri', 'net/http') do |url, options|
    options ||= {}
    url = build_url(url, options[:params]) if options[:params]
    Get.new(url).request(options)
  end

  def_which_requires(:build_url, 'cgi') do |url, params|
    url + (url[/\?/] ? '&' : "?") + params.map {|k,v| "#{k}=#{CGI.escape(v)}" }.join("&")
  end

  def_which_requires(:post, 'uri', 'net/http') do |url, options|
    Net::HTTP.post_form(URI.parse(url), options)
  end

  def install(url, options={}) #:nodoc:
    options[:name] ||= strip_name_from_url(url)
    return puts("Please give a library name for this url.") if options[:name].empty?
    filename = File.join ::Boson.repo.commands_dir, "#{options[:name]}.rb"
    return puts("Library name #{options[:name]} already exists. Try a different name.") if File.exists?(filename) && !options[:force]
    File.open(filename, 'w') {|f| f.write get(url) }

    if options[:method_wrap] || options[:module_wrap]
      file_string = File.read(filename)
      file_string = "def #{options[:name]}\n#{file_string}\nend" if options[:method_wrap]
      unless (mod_name = ::Boson::Util.camelize(options[:name]))
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

  # Used by the get command to make get requests and optionally parse json and yaml.
  # Ruby 1.8.x is dependent on json gem for parsing json.
  # See Get.request for options a request can take.
  class Get
    def initialize(url, options={})
      @url, @options = url, {:success_only=>true}.merge(options)
    end

    # Returns the response body string or a parsed data structure. Returns nil if request fails.
    # ==== Options:
    # [:success_only] Only return the body if the request code is successful i.e. 200. Default is true.
    # [:parse] Parse the body into either json or yaml. Expects a valid format or if true autodetects one.
    #          Default is false.
    # [:raise_error] Raises any original errors when parsing or fetching url instead of handling errors silently.
    def request(options={})
      @options.merge! options
      body = get_body
      body && @options[:parse] ? parse_body(body) : body
    end

    private
    # Returns body string if successful or nil if not.
    def get_body
      url = URI.parse(@url)
      if @options[:success_only]
        res = Net::HTTP.start(url.host, url.port) {|http| http.get(url.request_uri) }
        res.code == '200' ? res.body : nil
      else
        Net::HTTP.get(url)
      end
    rescue
      @options[:raise_error] ? raise :
        puts("Error: GET '#{@url}' -> #{$!.class}: #{$!.message}")
    end

    # Returns nil if dependencies or parsing fails
    def parse_body(body)
      format = determine_format(@options[:parse])
      case format
      when :json
        unless ::Boson::Util.safe_require 'json'
          return puts("Install the json gem to parse json: sudo gem install json")
        end
        JSON.parse body
      when :yaml
        YAML::load body
      else
        puts "Can't parse this format."
      end
    rescue
      @options[:raise_error] ? raise : puts("Error while parsing #{format} response of '#{@url}': #{$!.class}")
    end

    def determine_format(format)
      return format.to_sym if %w{json yaml}.include?(format.to_s)
      return :json if @url[/\.json$/]
      return :yaml if @url[/(\.yaml|\.yml)$/]
      nil
    end
  end
end