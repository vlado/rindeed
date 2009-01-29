module Rindeed
  # Container class for Indeed results that extends Array adding some additional methods that store Indeed metadata 
  class Results < Array
    attr_accessor :uri
    attr_accessor :success
    attr_accessor :query
    attr_accessor :location
    attr_accessor :dupefilter
    attr_accessor :highlight
    attr_accessor :totalresults
    attr_accessor :start
    attr_accessor :end
  end
end