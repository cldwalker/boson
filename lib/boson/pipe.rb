module Boson
  # This module passes an original command's return value through methods/commands specified as pipe options. Pipe options
  # are processed in this order:
  # * A :query option searches an array of objects or hashes using Pipe.search_object.
  # * A :sort option sorts an array of objects or hashes using Pipe.sort_object.
  # * All user-defined pipe options (:pipe_options key in Repo.config) are processed in random order.
  #
  # Some points:
  # * User-defined pipes call a command (the option's name by default). It's the user's responsibility to have this
  #   command loaded when used. The easiest way to do this is by adding the pipe command's library to :defaults in main config.
  # * By default, pipe commands do not modify the value their given. This means you can activate multiple pipes using
  #   a method's original return value.
  # * A pipe command expects a command's return value as its first argument. If the pipe option takes an argument, it's passed
  #   on as a second argument.
  # * See User Pipes section below for more about user pipes.
  # * When piping occurs in relation to rendering depends on the Hirb view. With the default Hirb view, piping occurs
  #   occurs in the middle of the rendering, after Hirb has converted the return value into an array of hashes.
  #   If using a custom Hirb view, piping occurs before rendering.
  #
  # === Default Pipes: Search and Sort
  # The default pipe options, :query, :sort and :reverse_sort, are quite useful for searching and sorting arrays:
  # Some examples using default commands:
  #   # Searches commands in the full_name field for 'lib' and sorts results by that field.
  #   bash> boson commands -q=f:lib -s=f    # or commands --query=full_name:lib --sort=full_name
  #
  #   # Multiple fields can be searched if separated by a ','. This searches the full_name and desc fields.
  #   bash> boson commands -q=f,d:web   # or commands --query=full_name,desc:web
  #
  #   # All fields can be queried using a '*'.
  #   # Searches all library fields and then reverse sorts on name field
  #   bash> boson libraries -q=*:core -s=n -R  # or libraries --query=*:core --sort=name --reverse_sort
  #
  #   # Multiple searches can be joined together by ','
  #   # Searches for libraries that have the name matching core or a library_type matching gem
  #   bash> boson libraries -q=n:core,l:gem   # or libraries --query=name:core,library_type:gem
  #
  # In these examples, we queried commands and examples with an explicit --query. However, -q or --query isn't necessary
  # for these commands because they already default to it when not present. This behavior comes from the default_option
  # attribute a command can have.
  #
  # === User Pipes
  # User pipes have the following attributes which alter their behavior:
  # [*:pipe*] Pipe command the pipe executes when called. Default is the pipe's name.
  # [*:env*] Boolean which enables passing an additional hash to the pipe command. This hash contains information from the first
  #          command's input with the following keys: :args (command's arguments), :options (command's options),
  #          :global_options (command's global options) and :config (a command's configuration hash). Default is false.
  # [*:filter*] Boolean which has the pipe command modify the original command's output with the value it returns. Default is false.
  # [*:no_render*] Boolean to turn off auto-rendering of the original command's final output. Only applicable to :filter enabled
  #                pipes. Default is false.
  # [*:solo*] Boolean to indicate this pipe should not be run with other user pipes. If a user calls multiple solo pipes,
  #           only the first one detected is called.
  #
  # === User Pipes Example
  # Let's say you want to have two commands, browser and copy, you want to make available as pipe options:
  #    # Opens url in browser. This command already ships with Boson.
  #    def browser(url)
  #      system('open', url)
  #    end
  #
  #    # Copy to clipboard
  #    def copy(str)
  #      IO.popen('pbcopy', 'w+') {|clipboard| clipboard.write(str)}
  #    end
  #
  # To configure them, drop the following config in ~/.boson/config/boson.yml:
  #   :pipe_options:
  #     :browser:
  #       :type: :boolean
  #       :desc: Open in browser
  #     :copy:
  #       :type: :boolean
  #       :desc: Copy to clipboard
  #
  # Now for any command that returns a url string, these pipe options can be turned on to execute the url.
  #
  # Some examples of these options using commands from {my libraries}[http://github.com/cldwalker/irbfiles]:
  #    # Creates a gist and then opens url in browser and copies it.
  #    bash> cat some_file | boson gist -bC        # or cat some_file | boson gist --browser --copy
  #
  #    # Generates rdoc in current directory and then opens it in browser
  #    irb>> rdoc '-b'    # or rdoc '--browser'
  module Pipe
    extend self

    # Main method which processes all pipe commands, both default and user-defined ones.
    def process(object, global_opt, env={})
      @env = env
      if object.is_a?(Array)
        object = search_object(object, global_opt[:query]) if global_opt[:query]
        object = sort_object(object, global_opt[:sort], global_opt[:reverse_sort]) if global_opt[:sort]
      end
      process_user_pipes(object, global_opt)
    end

    # Searches an array of objects or hashes using the :query option.
    # This option is a hash of fields mapped to their search terms. Searches are OR-ed.
    def search_object(object, query_hash)
      if object[0].is_a?(Hash)
        TableCallbacks.search_callback(object, :query=>query_hash)
      else
        query_hash.map {|field,query| object.select {|e| e.send(field).to_s =~ /#{query}/i } }.flatten.uniq
      end
    rescue NoMethodError
      $stderr.puts "Query failed with nonexistant method '#{$!.message[/`(.*)'/,1]}'"
    end

    # Sorts an array of objects or hashes using a sort field. Sort is reversed with reverse_sort set to true.
    def sort_object(object, sort, reverse_sort=false)
      if object[0].is_a?(Hash)
        TableCallbacks.sort_callback(object, :sort=>sort, :reverse_sort=>reverse_sort)
      else
        sort_lambda = object.all? {|e| e.send(sort).respond_to?(:<=>) } ? lambda {|e| e.send(sort) || ''} :
          lambda {|e| e.send(sort).to_s }
        object = object.sort_by &sort_lambda
        object = object.reverse if reverse_sort
        object
      end
    rescue NoMethodError, ArgumentError
      $stderr.puts "Sort failed with nonexistant method '#{sort}'"
    end

    # A hash that defines user pipes in the same way as the :pipe_options key in Repo.config.
    # This method should be called when a pipe's library is loading.
    def add_pipes(hash)
      pipe_options.merge! setup_pipes(hash)
    end

    #:stopdoc:
    def pipe_options
      @pipe_options ||= setup_pipes(Boson.repo.config[:pipe_options] || {})
    end

    def setup_pipes(hash)
      hash.each {|k,v| v[:pipe] ||= k }
    end

    def pipe(key)
      pipe_options[key] || {}
    end

    # global_opt can come from Hirb callback or Scientist
    def process_user_pipes(result, global_opt)
      pipes_to_process(global_opt).each {|e|
        args = [pipe(e)[:pipe], result]
        args << global_opt[e] unless pipe(e)[:type] == :boolean
        args << get_env(e, global_opt) if pipe(e)[:env]
        pipe_result = Boson.invoke(*args)
        result = pipe_result if pipe(e)[:filter]
      }
      result
    end

    def get_env(key, global_opt)
      { :global_options=>global_opt.merge(:delete_callbacks=>[:z_user_pipes]),
        :config=>(@env[:config].dup[key] || {}),
        :args=>@env[:args],
        :options=>@env[:options] || {}
      }
    end

    def any_no_render_pipes?(global_opt)
      !(pipes = pipes_to_process(global_opt)).empty? &&
        pipes.any? {|e| pipe(e)[:no_render] }
    end

    def pipes_to_process(global_opt)
      pipes = (global_opt.keys & pipe_options.keys)
      (solo_pipe = pipes.find {|e| pipe(e)[:solo] }) ? [solo_pipe] : pipes
    end
    #:startdoc:

    # Callbacks used by Hirb::Helpers::Table to search,sort and run custom pipe commands on arrays of hashes.
    module TableCallbacks
      extend self
      # Case-insensitive searches an array of hashes using the option :query. Numerical string keys
      # in :query are converted to actual numbers to interface with Hirb. See Pipe.search_object for more
      # about :query.
      def search_callback(obj, options)
        !options[:query] ? obj : begin
          options[:query].map {|field,query|
            field = field.to_i if field.to_s[/^\d+$/]
            obj.select {|e| e[field].to_s =~ /#{query}/i }
          }.flatten.uniq
        end
      end

      # Sorts an array of hashes using :sort option and reverses the sort with :reverse_sort option.
      def sort_callback(obj, options)
        return obj unless options[:sort]
        sort =  options[:sort].to_s[/^\d+$/] ? options[:sort].to_i : options[:sort]
        sort_lambda = (obj.all? {|e| e[sort].respond_to?(:<=>) } ? lambda {|e| e[sort] } : lambda {|e| e[sort].to_s })
        obj = obj.sort_by &sort_lambda
        obj = obj.reverse if options[:reverse_sort]
        obj
      end

      # Processes user-defined pipes in random order.
      def z_user_pipes_callback(obj, options)
        Pipe.process_user_pipes(obj, options)
      end
    end
  end
end
Hirb::Helpers::Table.send :include, Boson::Pipe::TableCallbacks