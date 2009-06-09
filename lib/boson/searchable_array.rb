module Boson
  # Searches array of hashes with a hash or string
  class SearchableArray < ::Array
    attr_accessor :default_search_field

    def default_search_field
      @default_search_field ||= :name
    end

    def search_fields
      @search_fields ||= self[0].keys.map {|e| e.to_s }.sort
    end

    def search(search_hash={})
      return self if search_hash.is_a?(Hash) && search_hash.empty?
      search_hash = {default_search_field=>search_hash} unless search_hash.is_a?(Hash)
      unalias_search_fields(search_hash)
      search_hash.inject(self) {|t,(k,v)| true_intersection(t, search_field(k,v)) }
    end

    def unalias_search_fields(search_hash)
      search_hash.each {|k,v|
        if !search_fields.include?(k) && (new_key = search_fields.detect {|e| e =~ /^#{k}/})
          search_hash[new_key.to_sym] = search_hash.delete(k)
        end
      }
    end

    def true_intersection(arr1, arr2)
      arr1.select {|e| arr2.include?(e)}
    end

    def search_field(field, term)
      self.select {|e| e[field].to_s =~ /#{term}/ }
    end
  end
end
