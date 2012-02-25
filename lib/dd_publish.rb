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
    
    @gapi = GData::Client::Apps.new(:version => 1.4)  #google sites api requires version 1.4 for some reason
    @gapi.source = 'indexdailydeets-0.1'
    @gapi.clientlogin(@username, @password, nil, nil, 'jotspot')  #http://code.google.com/intl/en/apis/sites/faq.html#AuthServiceName
             
  end
  
  def site_content
    body = @gapi.get("#{@base_url}/feeds/content/#{@domain}/#{@site}").body
    xml = XmlSimple.xml_in(body)
    
    pretty_xml = XmlSimple.xml_out(xml)
    
    puts
    puts pretty_xml
    puts
    
  end
  
  def add_page(title, content)       
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
    
    puts "posting new page: " + title
    #puts "PAYLOAD:\n" + payload
    
    @gapi.post("#{@base_url}/feeds/content/#{@domain}/#{@site}", payload)
  end
  
  def attach_file(title, filepath, parent_page)
    payload = %Q|
    <entry xmlns="http://www.w3.org/2005/Atom">
      <category scheme="http://schemas.google.com/g/2005#kind"
              term="http://schemas.google.com/sites/2008#attachment" label="attachment"/>
      <link rel="http://schemas.google.com/sites/2008#parent" type="application/atom+xml"
            href="https://sites.google.com/feeds/content/#{@domain}/#{@site}/#{parent_page}"/>
      <title>#{title}</title>
    </entry>
    |

    path = "#{@base_url}/feeds/content/#{@domain}/#{@site}"
    #https://sites.google.com/site/sp500dailydeets/fri-feb-24-2012-snp-500/gspc_200_day_dma_band.png?attredirects=0

    puts "PAYLOAD:\n#{payload}\n"
    puts "PATH: '#{path}'\n"

    @gapi.make_file_request(:post, path, filepath, 'image/png', payload)
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
    page_title = Date.today.strftime("%a %b %d, %Y SnP 500")

    page_title_url = page_title.downcase.gsub(/,/,'').gsub(/\s+/,'-')

    #PUBLISHER.add_page(page_title, html)
    PUBLISHER.attach_file('chart.png', File.join(directory, 'imgs/gspc_200_day_dma_band.png'), page_title_url)
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
