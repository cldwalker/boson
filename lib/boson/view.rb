module Boson
  # Handles {Hirb}[http://tagaholic.me/hirb/]-based views.
  module View
    extend self

    # Enables hirb and reads a config file from the main repo's config/hirb.yml.
    def enable
      Hirb::View.enable(:config_file=>File.join(Boson.repo.config_dir, 'hirb.yml')) unless @enabled
      @enabled = true
    end

    # Renders any object via Hirb. Options are passed directly to
    # {Hirb::Console.render_output}[http://tagaholic.me/hirb/doc/classes/Hirb/Console.html#M000011].
    def render(object, options={}, return_obj=false)
      if options[:inspect] || inspected_object?(object)
        puts(object.inspect)
      else
        render_object(object, options, return_obj)
      end
    end

    # Searches and sorts an array of objects or hashes using options :query, :sort and :reverse_sort.
    # The :query option is a hash of fields mapped to their search terms. Searches are OR-ed.
    def search_and_sort(object, options)
      if object.is_a?(Array)
        object = search_object(object, options[:query]) if options[:query]
        object = sort_object(object, options[:sort], options[:reverse_sort]) if object.size > 0 && options[:sort]
      end
      object
    end

    #:stopdoc:
    def toggle_pager
      Hirb::View.toggle_pager
    end

    def inspected_object?(obj)
      [nil,false,true].include?(obj)
    end

    def render_object(object, options={}, return_obj=false)
      options[:class] ||= :auto_table
      render_result = Hirb::Console.render_output(object, options)
      return_obj ? object : render_result
    end

    def search_object(object, query_hash)
      if object[0].is_a?(Hash)
        TableCallbacks.search_callback(object, :query=>query_hash)
      else
        query_hash.map {|field,query| object.select {|e| e.send(field).to_s =~ /#{query}/i } }.flatten.uniq
      end
    rescue NoMethodError
      $stderr.puts "Query failed with nonexistant method '#{$!.message[/`(.*)'/,1]}'"
    end

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
    #:startdoc:

    # Callbacks used by Hirb::Helpers::Table to search and sort arrays of hashes.
    module TableCallbacks
      extend self
      # Case-insensitive searches an array of hashes using the option :query. Numerical string keys
      # in :query are converted to actual numbers to interface with Hirb. See View.search_and_sort for more
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
    end
  end
end
Hirb::Helpers::Table.send :include, Boson::View::TableCallbacks