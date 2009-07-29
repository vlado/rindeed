require "hpricot" unless defined? Hpricot
require "will_paginate" unless defined? WillPaginate

require "rindeed/collection"
require "rindeed/results"
require "rindeed/view_helpers"
require "rindeed/version"
require 'rindeed'

module Rindeed
  API_SEARCH_URL = "http://api.indeed.com/ads/apisearch"
  
  @@publisher_id = ""
  @@jobs_per_page = 20
  @@default_options = {
    :sort => "relevance",
    :start => 0, 
    :limit => @@jobs_per_page, # 
    :fromage => 30, # 
    :filter => 1, # 
    :latlong => 0,
  }
  
  class << self
    
    # Used to setup default options that will be used in all queries.
    def default_options(options)
      @@default_options = @@default_options.merge(options)
    end
    
    # Used to setup your Publisher ID. The search won't work unless you set this.
    def publisher_id=(pub_id)
      @@publisher_id = pub_id
    end
    
    # Returns your Publisher ID.
    def publisher_id
      @@publisher_id
    end
    
    # Value set here will be used in all search unless you add <tt>:limit</tt> option to find (api_search) method
    def jobs_per_page=(per_page)
      @@jobs_per_page = per_page
    end
    
    # Sends search query to Indeed XML interface for <tt>what</tt> (job title, keywords or company name)
    # in the <tt>where</tt> (city, state or zip code) area and returns results as Rindeed::Results instance (Array with Indeed metadata)
    #
    # ==== Options
    # * <tt>:sort</tt> - Sort by <tt>relevance</tt> or <tt>date</tt>
    # * <tt>:start</tt> - Start results at this result number.
    # * <tt>:limit</tt> - Maximum number of results returned per query.
    # * <tt>:fromage</tt> - Number of days back to search. Max is 30.
    # * <tt>:filter</tt> - Filter duplicate results. 0 turns off duplicate job filtering.
    # * <tt>:latlong</tt> - If latlong=1, returns latitude and longitude information for each job result.
    # * <tt>:radius</tt> - Show jobs within (radius) miles radius
    # * <tt>:sr</tt> - Source employer (directhire) or job site (recruiters)
    # * <tt>:jt</tt> - Filter by job type (fulltime|parttime|contract|internship|temporary)
    # * <tt>:salary</tt> - Desired salary. :salary => 90000 will show only jobs with salary greater then $90000
    #
    # There can be even more options. See http://www.indeed.com/jsp/xmlsample.jsp or http://www.indeed.com/advanced_search for more info
    #
    # ==== Metadata
    # * <tt>uri</tt> - Full uri used to fetch results
    # * <tt>success</tt> - Request was succesfull <tt>true</tt> or unsuccesfull <tt>false</tt>
    # * <tt>query</tt> - what
    # * <tt>location</tt> - where
    # * <tt>dupefilter</tt> - Duplicates are filtered <tt>true</tt> or not <tt>false</tt> (see options[:filter])
    # * <tt>highlight</tt> - ?
    # * <tt>totalresults</tt> - Total results for provided query
    # * <tt>start</tt> - see options[:start]
    # * <tt>end</tt> - options[:start] + options[:limit]
    def api_search(what, where, options={})
      uri = assemble_uri(what, where, @@default_options.merge(options))
      results = self::Results.new
      results.uri = uri
      results.success = false
      begin
        doc = Hpricot(Net::HTTP.get(URI(uri)))
        response = doc.at('response')
        results.query = response.at('query').inner_html
        results.location = response.at('location').inner_html
        results.dupefilter = determine_dupefilter(response)
        results.highlight = determine_highlight(response)
        results.totalresults = response.at('totalresults').inner_html.to_i
        results.start = response.at('start').inner_html.to_i
        results.end = response.at('end').inner_html.to_i
        response.search('result').each { |res| results << parse_result(res) }
        results.success = true
      rescue
        results.totalresults = 0
      end
      results
    end
    
    # Alias for api_search method
    alias_method :find, :api_search
    
    # Similar to api_search (find) method, with differnce that it returns Rindeed::Collection allowing us to use will_paginate functionality
    # for pagination
    # ==== Options
    # * <tt>:page</tt> - REQUIRED, but defaults to 1 if false or nil
    # All other options are identical as with api_search method
    #
    # See http://mislav.uniqpath.com/static/will_paginate/doc/ for more info
    def paginate(what, where, options={})
      default_options = @@default_options.merge({ :page => 1, :limit => @@jobs_per_page })
      options[:limit] = options[:per_page] if options[:per_page]
      opts = default_options.merge(options)
      results = self::Collection.create(opts[:page], opts[:limit]) do |pager|
        opts[:limit] = pager.per_page
        opts[:start] = pager.offset
        result = self.api_search(what, where, opts)
        pager.replace(result) # inject the result array into the paginated collection
        unless pager.total_entries # the pager didn't manage to guess the total count, do it manually
          pager.total_entries = pager.totalresults
        end
        pager.total_entries = 1000 if pager.total_entries > 1000 # limits number of jobs to 1000 (max that Indeed API returns)
      end
    end
    
    # Counts total number of jobs. Params and options are same as for api_search
    def count(what, where, options={})
      opts = @@default_options.merge(options)
      opts[:limit] = 1
      uri = assemble_uri(what, where, opts)
      begin
        doc = Hpricot(Net::HTTP.get(URI(URI.escape(uri))))
        total_results = doc.at('totalresults').inner_html.to_i
      rescue
        total_results = 0
      end
      total_results
    end
    
    private
    
    def assemble_uri(what, where, options={})
      uri = "#{API_SEARCH_URL}?publisher=#{@@publisher_id}&q=#{what}&l=#{where}" # &start=#{start}&limit=#{limit}"
      options.each { |key,value| uri << "&#{key}=#{value}" }
      URI.escape(uri)
    end
    
    # result = Hpricot element
    def parse_result(result)
      data = {}
      result.containers.each do |c|
        data[c.name.to_sym] = c.name=="date" ? DateTime.parse(c.inner_html) : c.inner_html
      end
      data
    end
    
    def determine_dupefilter(response)
      dupefilter = response.at('dupefilter').inner_html
      dupefilter=="true" ? true : false
    end
    
    def determine_highlight(response)
      highlight = response.at('highlight').inner_html
      highlight=="false" ? false : highlight
    end
    
  end

end