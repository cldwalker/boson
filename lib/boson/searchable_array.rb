module Boson
  # Searches array of hashes with a hash or string
  class SearchableArray < ::Array
    attr_accessor :default_search_field

    def find_by(search_hash)
      @search_proc = nil
      @search_mode = :exact
      results = hash_search(search_hash)
      results.is_a?(Array) ? results[0] : results
    end

    def search(search_hash=nil, defaults={})
      @search_mode = @search_proc = nil
      search_hash = {} if search_hash.nil?
      search_hash = {default_search_field=>search_hash} unless search_hash.is_a?(Hash)
      search_hash = defaults.merge(search_hash) unless defaults.empty?
      return self if search_hash.empty?
      unalias_search_fields(search_hash)
      hash_search(search_hash)
    end

    #:stopdoc:
    def default_search_field
      @default_search_field ||= :name
    end

    def search_fields
      @search_fields ||= self[0].keys.map {|e| e.to_s }.sort
    end

    def hash_search(search_hash)
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
      self.select {|e| search_proc.call(e, field, term) }
    end

    def search_proc
      @search_proc ||= (@search_mode == :exact) ? lambda {|h,k,v| h[k] == v } : lambda {|h,k,v| h[k].to_s =~ /#{v}/ }
    end
  end
end
