require 'dd_logger'
require 'gdata'
require 'xmlsimple'



class GoogleSitesPublisher

  def initialize(username, password, site)
    @username, @password, @site = username, password, site
    
    @base_url = 'https://sites.google.com'
    @domain = 'site'

    #most requests are done to this url
    @site_url = "#{@base_url}/feeds/content/#{@domain}/#{@site}"
    
    @gapi = nil  #login happens when first request is made, so this is nil for now
  end

  #login only once
  def login
    #google sites api requires version 1.4 for some reason
    unless @gapi
      Log.info "Logging into google sites with username '#{@username}'"
      @gapi = GData::Client::Apps.new(:version => 1.4)
      @gapi.source = 'indexdailydeets-0.1'
      @gapi.clientlogin(@username, @password, nil, nil, 'jotspot')  #http://code.google.com/intl/en/apis/sites/faq.html#AuthServiceName
    end
  end
  
  def site_content
    login
    body = @gapi.get(@site_url).body
    xml = XmlSimple.xml_in(body)
    
    pretty_xml = XmlSimple.xml_out(xml)

    Log.debug "Site content:\n\n#{pretty_xml}\n"

    pretty_xml
  end
  
  def add_page(title, content)       
    login
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
    login
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
    html_filename = Dir["#{directory}/*.html"][0]

    html = File.read(html_filename)

    title_filename = Dir["#{directory}/*.title"][0]
    page_title_file = File.open (title_filename)
    page_title = page_title_file.readline
    page_title_file.close
    Log.debug "Read page title: '#{page_title}'"

    #page_title_url = page_title.downcase.gsub(/,/,'').gsub(/\s+/,'-')

    new_page_id = PUBLISHER.add_page(page_title, html)

    #images need to be uploaded..
    images = Dir["#{directory}/**/*.png"].map {|f| f.match(/^#{directory}\/(.*)$/)[1]}
    Log.debug "Publishing image files: #{images.inspect}"
    images.each do |image_file|
      PUBLISHER.attach_file(image_file, File.join(directory, image_file), new_page_id)
    end
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
