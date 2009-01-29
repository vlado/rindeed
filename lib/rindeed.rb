module Rindeed
  PUBLISHER_ID = "enter you publisher id (key) here"
  API_SEARCH_URL = "http://api.indeed.com/ads/apisearch"
  JOBS_PER_PAGE = 20
  DEFAULT_OPTIONS = {
    :sort => "relevance",
    :start => 0, 
    :limit => JOBS_PER_PAGE, # 
    :fromage => 30, # 
    :filter => 1, # 
    :latlong => 0,
  }
  
  class << self
    
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
    #
    # # see http://www.indeed.com/jsp/xmlsample.jsp for more info about options
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
      uri = assemble_uri(what, where, DEFAULT_OPTIONS.merge(options))
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
      default_options = DEFAULT_OPTIONS.merge({ :page => 1, :limit => JOBS_PER_PAGE })
      options[:limit] = options[:per_page] if options[:per_page]
      opts = default_options.merge(options)
      results = self::Collection.create(opts[:page], opts[:limit]) do |pager|
        opts[:limit] = pager.per_page
        opts[:start] = pager.offset
        result = self.api_search(what, where, opts)
        pager.replace(result) # inject the result array into the paginated collection
        unless pager.total_entries # the pager didn't manage to guess the total count, do it manually
          #pager.total_entries = self.count(what, where, opts)
          pager.total_entries = pager.totalresults
        end
      end
    end
    
    # Counts total number of jobs
    # Params and options are same as for api_search
    def count(what, where, options={})
      opts = DEFAULT_OPTIONS.merge(options)
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
      uri = "#{API_SEARCH_URL}?publisher=#{PUBLISHER_ID}&q=#{what}&l=#{where}" # &start=#{start}&limit=#{limit}"
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