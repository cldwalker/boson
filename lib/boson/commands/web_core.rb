module Boson::Commands::WebCore
  extend self

  def config #:nodoc:
    commands = {
      'get'=>{ :desc=>"Gets the body of a url", :args=>[['url'],['options', {}]]},
      'post'=>{ :desc=>'Posts to a url', :args=>[['url'],['options', {}]]},
      'build_url'=>{ :desc=>"Builds a url, escaping the given params", :args=>[['url'],['params']]},
      'browser'=>{ :desc=>"Opens urls in a browser on a Mac"},
      'install'=>{ :desc=>"Installs a library by url. Library should then be loaded with load_library.",
        :args=>[['url'],['options', {}]],
        :options=> { :name=>{:type=>:string, :desc=>"Library name to save to"},
          :force=>{:type=>:boolean, :desc=>'Overwrites an existing library'},
          :default=>{:type=>:boolean, :desc=>'Adds library as a default library to main config file'},
          :module_wrap=>{:type=>:boolean, :desc=>"Wraps a module around install using library name"},
          :method_wrap=>{:type=>:boolean, :desc=>"Wraps a method and module around installed library using library name"}}
      }
    }

    {:library_file=>File.expand_path(__FILE__), :commands=>commands, :namespace=>false}
  end

  # Requires libraries only once before defining method with given block
  def self.def_which_requires(meth, *libs, &block)
    define_method(meth) do |*args|
      libs.each {|e| require e }
      define_method(meth, block).call(*args)
    end
  end

  def_which_requires(:get, 'net/https') do |*args|
    url, options = args[0], args[1] || {}
    url = build_url(url, options[:params]) if options[:params]
    Get.new(url).request(options)
  end

  def_which_requires(:build_url, 'cgi') do |url, params|
    url + (url[/\?/] ? '&' : "?") + params.map {|k,v|
      v = v.is_a?(Array) ? v.join(' ') : v.to_s
      "#{k}=#{CGI.escape(v)}"
    }.join("&")
  end

  def_which_requires(:post, 'uri', 'net/http') do |*args|
    url, options = args[0], args[1] || {}
    (res = Net::HTTP.post_form(URI.parse(url), options)) && res.body
  end

  def install(url, options={}) #:nodoc:
    options[:name] ||= strip_name_from_url(url)
    return puts("Please give a library name for this url.") if options[:name].empty?
    filename = File.join ::Boson.repo.commands_dir, "#{options[:name]}.rb"
    return puts("Library name #{options[:name]} already exists. Try a different name.") if File.exists?(filename) && !options[:force]

    file_string = get(url) or raise "Unable to fetch url"
    file_string = "# Originally from #{url}\n"+file_string
    file_string = wrap_install(file_string, options) if options[:method_wrap] || options[:module_wrap]

    File.open(filename, 'w') {|f| f.write file_string }
    Boson.repo.update_config {|c| (c[:defaults] ||= []) << options[:name] } if options[:default]
    puts "Saved to #{filename}."
  end

  # non-mac users should override this with the launchy gem
  def browser(*urls)
    system('open', *urls)
  end

  private
  def wrap_install(file_string, options)
    indent = "  "
    unless (mod_name = ::Boson::Util.camelize(options[:name]))
      return puts("Can't wrap install with name #{options[:name]}")
    end

    file_string.gsub!(/(^)/,'\1'+indent)
    file_string = "def #{options[:name]}\n#{file_string}\nend".gsub(/(^)/,'\1'+indent) if options[:method_wrap]
    "module #{mod_name}\n#{file_string}\nend"
  end

  def strip_name_from_url(url)
    url[/\/([^\/.]+)(\.[a-z]+)?$/, 1].to_s.gsub('-', '_').gsub(/[^a-zA-Z_]/, '')
  end

  # Used by the get command to make get requests and optionally parse json and yaml.
  # Ruby 1.8.x is dependent on json gem for parsing json.
  # See Get.request for options a request can take.
  class Get
    FORMAT_HEADERS = {
      :json=>%w{application/json text/json application/javascript text/javascript},
      :yaml=>%w{application/x-yaml text/yaml}
    } #:nodoc:

    def initialize(url, options={})
      @url, @options = url, options
    end

    # Returns the response body string or a parsed data structure. Returns nil if request fails. By default expects response
    # to be 200.
    # ==== Options:
    # [:any_response] Returns body string for any response code. Default is false.
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
      uri = URI.parse(@url)
      @response = get_response(uri)
      (@options[:any_response] || @response.code == '200') ? @response.body : nil
    rescue
      @options[:raise_error] ? raise : puts("Error: GET '#{@url}' -> #{$!.class}: #{$!.message}")
    end

    def get_response(uri)
      net = Net::HTTP.new(uri.host, uri.port)
      net.verify_mode = OpenSSL::SSL::VERIFY_NONE if uri.scheme == 'https'
      net.use_ssl = true if uri.scheme == 'https'
      net.start {|http|  http.request_get(uri.request_uri) }
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
      return :json if FORMAT_HEADERS[:json].include?(@response.content_type)
      return :yaml if FORMAT_HEADERS[:yaml].include?(@response.content_type)
      nil
    end
  end
end
