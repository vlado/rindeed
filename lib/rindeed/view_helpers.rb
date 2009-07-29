module Rindeed
  module ViewHelpers
    
    # Returns html with jobs by indeed attribution
     def indeed_attribution
        '<span id="indeed_at">
      		some <a href="http://www.indeed.com/?indpubnum='+Rindeed.publisher_id.to_s+'" target="_blank">jobs</a> by <a href="http://www.indeed.com/?indpubnum='+Rindeed.publisher_id.to_s+'" title="Job Search"  target="_blank">
      			<img src="http://www.indeed.com/p/jobsearch.gif" style="border:0;vertical-align:middle;" alt="job search" />
      		</a>
      	</span>'
      end
    
    # Returns an html script tag for js file needed by indeed
    def include_indeed_js
      '<script src="http://www.indeed.com/ads/apiresults.js" type="text/javascript"></script>'
    end
    
    # Returns text containing company name and location for provided job. See also <tt>indeed_job_location</tt> for options
    def indeed_job_company_with_location(job, options={})
      default_options = {
        :show_country => false
      }
      opts = default_options.merge(options)
      text = ""
      unless job[:company].to_s.empty?
        text = job[:company]
      end
      location = indeed_job_location(job, opts)
      unless location.empty?
        if text.empty?
          text = location.to_s
        else
          text << " - #{location}"
        end
      end
      text
    end
    
    # Returns location for provided job
    #
    # ==== Options
    # * <tt>:show_country</tt> - set to <tt>true</tt> if you want country to be included in location
    def indeed_job_location(job, options={})
      default_options = {
        :show_country => false
      }
      opts = default_options.merge(options)
      location = job[:city].to_s
      if location.empty?
        location = job[:state].to_s
      else
        location << ", #{job[:state]}"
      end
      if opts[:show_country]
        if location.empty?
          location = job[:country].to_s
        else
          location << ", #{job[:country]}"
        end
      end
      location
    end
    
  end
end