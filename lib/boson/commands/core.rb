module Boson
  module Commands
    module Core
      def commands(query='', options={})
        options = {:fields=>[:name, :lib, :alias],:search_field=>:name}.merge(options)
        search_field = options.delete(:search_field)
        results = Boson.commands.select {|f| f.send(search_field) =~ /#{query}/ }
        render results, options
      end

      def libraries(query='', options={})
        options = {:fields=>[:name, :loaded, :commands, :gems], :search_field=>:name,
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
        ::Hirb::Console.render_output(object, options)
      end

      def menu(output, options={}, &block)
        ::Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
      end

      def get(url)
        require 'net/http'
        Net::HTTP.get(URI.parse(url))
      end

      def download(url)
        require 'fileutils'
        FileUtils.mkdir_p(File.join(Boson.dir,'downloads'))
        response = get(url)
        filename = determine_download_name(url)
        File.open(filename, 'w') { |f| f.write response }
        filename
      end

      private
      def determine_download_name(url)
        require 'uri'
        basename = URI.parse(url).path.split('/')[-1]
        basename = URI.parse(url).host.sub('www.','') if basename.nil? || basename.empty?
        filename = File.join(Boson.dir, 'downloads', basename)
        filename += "-#{Time.now.strftime("%m_%d_%y_%H_%M_%S")}" if File.exists?(filename)
        filename
      end
    end
  end
end