module Rindeed
  # Slightly modified WillPaginate::Collection class to be able to recieve Indeed metadata from Rindeed::Results
  class Collection < WillPaginate::Collection
    attr_accessor :uri
    attr_accessor :success
    attr_accessor :query
    attr_accessor :location
    attr_accessor :dupefilter
    attr_accessor :highlight
    attr_accessor :totalresults
    attr_accessor :start
    attr_accessor :end
    
    # See http://github.com/mislav/will_paginate for doc and original method
    # I've changed it to copy indeed metadata from Rindeed::Results to collection
    def replace(array)
      result = super
      copy_indeed_metadata(array) # Line that I added (copy indeed metadata to collection)  
      if total_entries.nil? and length < per_page and (current_page == 1 or length > 0)
        self.total_entries = offset + length
      end
      result
    end
    
    private
    
    # copies indeed metadata from Rindeed::Results instance
    def copy_indeed_metadata(result)
      self.uri = result.uri
      self.success = result.success
      self.query = result.query
      self.location = result.location
      self.dupefilter = result.dupefilter
      self.highlight = result.highlight
      self.totalresults = result.totalresults
      self.start = result.start
      self.end = result.end
      return true
    end
    
  end
end