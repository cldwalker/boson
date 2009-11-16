module Boson
  # This module passes a command's return value through methods/commands specified as pipe options. Pipe options
  # are processed in this order:
  # * A :query option searches an array of objects or hashes using Pipe.search_object.
  # * A :sort option sorts an array of objects or hashes using Pipe.sort_object.
  # * All user-defined pipe options (:pipe_options key in Repo.config) are processed in any order.
  #
  # Note that if a command is rendering with the default Hirb view, piping actually occurs after Hirb
  # has converted the return value into an array of hashes. If using your own custom Hirb view, piping occurs
  # before rendering.
  module Pipe
    extend self

    # Main method which processes all pipe commands, both default and user-defined ones.
    def process(object, options)
      if object.is_a?(Array)
        object = search_object(object, options[:query]) if options[:query]
        object = sort_object(object, options[:sort], options[:reverse_sort]) if options[:sort]
      end
      process_user_pipes(object, options)
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

    #:stopdoc:
    def pipe_options
      @pipe_options ||= Boson.repo.config[:pipe_options] || {}
    end

    def process_user_pipes(result, options)
      (options.keys & pipe_options.keys).each {|e|
        command = pipe_options[e][:pipe] ||= e
        pipe_result = pipe_options[e][:type] == :boolean ? Boson.invoke(command, result) :
          Boson.invoke(command, result, options[e])
        result = pipe_result if pipe_options[e][:filter]
      }
      result
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
        sort =  options[:sort].to_s[/^\d+$/] ? options[:sort].to_i : options[:sort]
        sort_lambda = (obj.all? {|e| e[sort].respond_to?(:<=>) } ? lambda {|e| e[sort] } : lambda {|e| e[sort].to_s })
        obj = obj.sort_by &sort_lambda
        obj = obj.reverse if options[:reverse_sort]
        obj
      end

      # Processes user-defined pipes in any order.
      def z_user_pipes_callback(obj, options)
        Pipe.process_user_pipes(obj, options)
      end
    end
  end
end
Hirb::Helpers::Table.send :include, Boson::Pipe::TableCallbacks