require 'dd_logger'
require 'dd_csv_io'

require 'ohash'

module YahooHistoricalData
  require 'json'
  require 'net/http'

  def self.format_yahoo_date date
    date.strftime('%Y-%m-%d')
  end

  def self.make_quote_ohash hash
    quote = OpenHash.new
    hash.each_pair do |key, value|
      quote[key.downcase.intern] = value
    end

    #convert strings into proper ruby data types using the same proc used in csv parsing
    quote.each_pair do |key,value|
      quote[key] = CSV_IO::YF_READER_CONVERTER.call value
    end

    Log.debug "Processed quote #{quote.inspect}"

    quote
  end

  def self.get_historical_data symbol, start_date, end_date
    base_url = 'http://query.yahooapis.com/v1/public/yql'
    query = URI.encode %Q{select * from yahoo.finance.historicaldata where symbol = "#{symbol}" and startDate='#{format_yahoo_date start_date}' and endDate = '#{format_yahoo_date end_date}'}
    format = 'json'
    env= URI.encode 'store://datatables.org/alltableswithkeys'
    url = base_url + "?q=#{query}&format=#{format}&env=#{env}"

    Log.debug "Doing get to #{url}"
    resp = Net::HTTP.get_response(URI.parse(url))
    result = JSON.parse(resp.body)
    Log.debug "Got back '#{result}'"

    quote_ohashes = []
    return quote_ohashes unless result['query'] && result['query']['results'] && result['query']['results']['quote']
    quotes = result['query']['results']['quote']

    case quotes
      when Array
        quotes.each do |quote|
          quote_ohashes << make_quote_ohash(quote)
        end

      when Hash
        quote_ohashes << make_quote_ohash(quotes)

      else
        raise "dont know how to make a quote from a #{quotes.class}"
    end

    quote_ohashes
  end
end

module DD_Updater
  include CSV_IO

  def update_historical_csv symbol, filename

    Log.debug "Checking to see if historical data update is needed for #{symbol}"
    #see what day we have in csv
    date_of_last = csv_read(filename, :rows => 1, :converter => CSV_IO::YF_READER_CONVERTER)[0][:date]
    Log.debug "date of top row in csv: #{date_of_last}"

    today = Date.today
    Log.debug "now: #{today}"

    if date_of_last >= today
      Log.warn "No update needed"
      return
    end

    new_data = YahooHistoricalData.get_historical_data symbol, date_of_last+1, today

    unless new_data.length > 0
      Log.error "No quote data returned"
      return
    end

    Log.debug "writing new csv data"
    #TODO optomize this so it just merges the new csv data into the existing file, insteading of writing it out again completely
    full_data = csv_read(filename, :converter => CSV_IO::YF_READER_CONVERTER)
    full_data = new_data + full_data
    csv_write(filename, full_data, :converter => CSV_IO::YF_WRITER_CONVERTER )
    Log.debug "wrote ''#{new_data.length}'' rows of new csv data, for #{full_data.length} total rows of data"
  end

end

#test code
if __FILE__ == $0
  require 'test/unit'

  include DD_Updater

  TEST_CSV = 'lib/test_data/^GSPC.csv'

  class TestDDUpdater < Test::Unit::TestCase
    def test_updater_historical_single_day
      update_historical_csv '^GSPC', TEST_CSV
    end

  end

end