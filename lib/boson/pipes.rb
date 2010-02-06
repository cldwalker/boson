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
    def query_pipe(object, query_hash)
      if object[0].is_a?(Hash)
        query_hash.map {|field,query|
          field = field.to_i if field.to_s[/^\d+$/]
          object.select {|e| e[field].to_s =~ /#{query}/i }
        }.flatten.uniq
      else
        query_hash.map {|field,query| object.select {|e| e.send(field).to_s =~ /#{query}/i } }.flatten.uniq
      end
    rescue NoMethodError
      $stderr.puts "Query failed with nonexistant method '#{$!.message[/`(.*)'/,1]}'"
    end

    # Sorts an array of objects or hashes using a sort field. Sort is reversed with reverse_sort set to true.
    def sort_pipe(object, sort)
      sort_lambda = lambda {}
      if object[0].is_a?(Hash)
        sort = sort.to_i if sort.to_s[/^\d+$/]
        sort_lambda = (object.all? {|e| e[sort].respond_to?(:<=>) } ? lambda {|e| e[sort] } : lambda {|e| e[sort].to_s })
      else
        sort_lambda = object.all? {|e| e.send(sort).respond_to?(:<=>) } ? lambda {|e| e.send(sort) || ''} :
          lambda {|e| e.send(sort).to_s }
      end
      object.sort_by &sort_lambda
    rescue NoMethodError, ArgumentError
      $stderr.puts "Sort failed with nonexistant method '#{sort}'"
    end

    # Reverse an object
    def reverse_sort_pipe(object, extra=nil)
      object.reverse
    end

    # Pipes multiple commands
    def pipes_pipe(obj, arr)
      arr.inject(obj) {|acc,e| Boson.full_invoke(e, [acc]) }
    end
  end
end