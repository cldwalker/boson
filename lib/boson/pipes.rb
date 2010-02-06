module Boson
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
  module Pipes
    extend self

    # Case-insensitive search an array of objects or hashes for the :query option.
    # This option is a hash of fields mapped to their search terms. Searches are OR-ed.
    # When searching hashes, numerical string keys in query_hash are converted to actual numbers to
    # interface with Hirb.
    def search_pipe(object, query_hash)
      if object[0].is_a?(Hash)
        search_hash(object, :query=>query_hash)
      else
        query_hash.map {|field,query| object.select {|e| e.send(field).to_s =~ /#{query}/i } }.flatten.uniq
      end
    rescue NoMethodError
      $stderr.puts "Query failed with nonexistant method '#{$!.message[/`(.*)'/,1]}'"
    end

    # Sorts an array of objects or hashes using a sort field. Sort is reversed with reverse_sort set to true.
    def sort_pipe(object, sort, reverse_sort=false)
      if object[0].is_a?(Hash)
        sort_hash(object, :sort=>sort, :reverse_sort=>reverse_sort)
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

    def pipes_pipe(obj, arr)
      arr.inject(obj) {|acc,e| Boson.full_invoke(e, [acc]) }
    end

    def search_hash(obj, options) #:nodoc:
      !options[:query] ? obj : begin
        options[:query].map {|field,query|
          field = field.to_i if field.to_s[/^\d+$/]
          obj.select {|e| e[field].to_s =~ /#{query}/i }
        }.flatten.uniq
      end
    end

    def sort_hash(obj, options) #:nodoc:
      return obj unless options[:sort]
      sort =  options[:sort].to_s[/^\d+$/] ? options[:sort].to_i : options[:sort]
      sort_lambda = (obj.all? {|e| e[sort].respond_to?(:<=>) } ? lambda {|e| e[sort] } : lambda {|e| e[sort].to_s })
      obj = obj.sort_by &sort_lambda
      obj = obj.reverse if options[:reverse_sort]
      obj
    end
  end
end