require 'dd_logger'
require 'gdata'
require 'xmlsimple'

class GoogleSitesPublisher

  RequiredInformation = [
    :username,
    :password,
    :site,
  ]
  
  def initialize(username, password, site)
    @username, @password, @site = username, password, site
    
    @base_url = 'https://sites.google.com'
    @domain = 'site'

    #most requests are done to this url
    @site_url = "#{@base_url}/feeds/content/#{@domain}/#{@site}"
    
    @gapi = GData::Client::Apps.new(:version => 1.4)  #google sites api requires version 1.4 for some reason
    @gapi.source = 'indexdailydeets-0.1'
    @gapi.clientlogin(@username, @password, nil, nil, 'jotspot')  #http://code.google.com/intl/en/apis/sites/faq.html#AuthServiceName
             
  end
  
  def site_content
    body = @gapi.get(@site_url).body
    xml = XmlSimple.xml_in(body)
    
    pretty_xml = XmlSimple.xml_out(xml)

    Log.debug "Site content:\n\n#{pretty_xml}\n"

    pretty_xml
  end
  
  def add_page(title, content)       
    Log.info "posting new page: " + title

    payload = %Q|
    <entry xmlns="http://www.w3.org/2005/Atom">
        <category scheme="http://schemas.google.com/g/2005#kind"
            term="http://schemas.google.com/sites/2008#webpage" label="webpage"/>
        <title>#{title}</title>
        <content type="xhtml">
          <div xmlns="http://www.w3.org/1999/xhtml">#{content}</div>
        </content>
      </entry>
    |
    
    Log.debug "PAYLOAD:\n#{payload}\n"
    
    response = @gapi.post(@site_url, payload)

    body = XmlSimple.xml_in(response.body)

    #Log.debug "Response body:\n\n#{response.body}\n\n#{body.inspect}"

    #send back the id of the new page so we can attach files to it
    id = body["id"][0].match(/\/(\d+)$/)[1]
    Log.info "New page's id is: '#{id}'"
    id
  end
  
  def attach_file(title, filepath, parent_page_id)
    Log.info "Attaching file '#{filepath}' to page '#{parent_page_id}'"

    payload = %Q|
    <entry xmlns="http://www.w3.org/2005/Atom">
      <category scheme="http://schemas.google.com/g/2005#kind"
              term="http://schemas.google.com/sites/2008#attachment" label="attachment"/>
      <link rel="http://schemas.google.com/sites/2008#parent" type="application/atom+xml"
            href="#{@site_url}/#{parent_page_id}"/>
      <title>#{title}</title>
    </entry>
    |

    @gapi.make_file_request(:post, @site_url, filepath, 'image/png', payload)
  end
  
end

require 'yaml'
module DD_Publisher
  
  config = YAML.load_file('google_sites.yml')

  
  PUBLISHER = GoogleSitesPublisher.new(config['username'], config['password'], config['site'])
  
  def publish(directory='output')    
    html = File.read(File.join(directory,'goog_site.html'))

    #should use static data from historical output for page title
    #will look like: 'Fri Feb 17 2012 SnP 500'
    page_title = Time.now.strftime("%a %b %d, %Y SnP 500 %H:%M:%S")

    page_title_url = page_title.downcase.gsub(/,/,'').gsub(/\s+/,'-')

    new_page_id = PUBLISHER.add_page(page_title, html)
    PUBLISHER.attach_file('gspc_200_day_dma_band.png', File.join(directory, 'imgs/gspc_200_day_dma_band.png'), new_page_id)
  end
  
end

if __FILE__ == $0
   require 'test/unit'

  include DD_Publisher

  TEST_HTML_TO_PUBLISH = 'output/goog_site.html'
  
  class TestDDPublish < Test::Unit::TestCase
    
    def xtest_google_publish
      gp = GooglePublisher.new('username','password', 'site_name')
      
      gp.site_content          
    end
    
    def test_publish_output_directory
      publish('output')
    end
  end
    
end
