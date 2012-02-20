require 'dd_logger'
require 'gdata'

class GooglePublisher
  
  def initialize(username, password, site)
    @username, @password, @site = username, password, site
    
    @gapi = GData::Client::Apps.new(:version => 1.4)
    @gapi.source = 'indexdailydeets-0.1'
    @gapi.clientlogin(@username, @password, nil, nil, 'jotspot')         
  end
  
  def feeds_content_site
    @gapi.get("https://sites.google.com/feeds/content/site/#{@site}").body
  end
  
  
end


module DD_Publish
  
  
  
  
end


if __FILE__ == $0
   require 'test/unit'

  #include DD_Publish

  TEST_HTML_TO_PUBLISH = 'output/goog_site.html'
  
  class TestDDPublish < Test::Unit::TestCase
    
    def test_google_publish
      gp = GooglePublisher.new('username','password', 'site_name')
      puts gp.feeds_content_site
    end
  end
    
end
