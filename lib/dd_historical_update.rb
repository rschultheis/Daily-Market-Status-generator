require 'dd_logger'
require 'dd_csv_io'

require 'ohash'

module YahooData
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

  def self.execute_yql query_string
    base_url = 'http://query.yahooapis.com/v1/public/yql'
    query = URI.encode query_string
    format = 'json'
    env= URI.encode 'store://datatables.org/alltableswithkeys'
    url = base_url + "?q=#{query}&format=#{format}&env=#{env}"

    Log.debug "Doing yql query get to #{url}"
    resp = Net::HTTP.get_response(URI.parse(url))
    result = JSON.parse(resp.body)
    Log.debug "Got back '#{result}'"
    result
  end

  def self.get_historical_data symbol, start_date, end_date
    result = execute_yql %Q{select * from yahoo.finance.historicaldata where symbol = "#{symbol}" and startDate='#{format_yahoo_date start_date}' and endDate = '#{format_yahoo_date end_date}'}

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

  def self.get_current_quote symbol
    result = execute_yql %Q|select * from yahoo.finance.quotes where symbol = "#{symbol}"|

    quote = result['query']['results']['quote']

    Log.debug "full quote = #{quote.inspect}"

   qhash = {
      :date       => quote["LastTradeDate"],
      :open       => quote["Open"],
      :high       => quote["DaysHigh"],
      :low        => quote["DaysLow"],
      :close      => quote["LastTradePriceOnly"],
      :volume     => quote["Volume"],
      :adj_close  => quote["LastTradePriceOnly"],
    }
    make_quote_ohash qhash
  end
end

module DD_Updater
  include CSV_IO

  def update_historical_csv symbol, filename

    Log.debug "Checking to see if historical data update is needed for #{symbol}"
    #see what day we have in csv
    last_updated_date  = csv_read(filename, :rows => 1)[0][:date]
    Log.debug "date of top row in csv: #{last_updated_date }"


    #market closes at 4, and closing quotes are up at 4:15, so take off 16.25 hours, so if 4:15 has passed DateTime.now will still be in today
    date_of_last_close = DateTime.now - (16.25/24.0)
    #truncate to just the date for comparison, get a better way of doing this than to a string and back?
    date_of_last_close= Date.parse(date_of_last_close.to_s)

    #if today is saturday or sunday, update to the friday before
    update_to_date  = case date_of_last_close.wday
                  when 6
                    date_of_last_close - 1.0 #if saturday take off one day
                  when 0
                    date_of_last_close - 2.0 #if sunday take off two days
                  else
                    date_of_last_close
                  end


    Log.debug "update-to: #{update_to_date .strftime('%Y-%m-%d')}"

    if last_updated_date  >= update_to_date
      Log.warn "No update needed"
      return
    end

    new_data = []
    while last_updated_date < update_to_date

      if (update_to_date - last_updated_date).to_f == 1.0
        Log.debug "Doing daily quote update since only one day since last update"

        new_data = [ YahooData.get_current_quote(symbol) ]
      else
        Log.debug "Doing historical update since more than one day since last update"

        new_data = YahooData.get_historical_data symbol, last_updated_date +1, update_to_date
      end
      unless new_data.length > 0
        Log.error "No quote data returned"
        return
      end

      Log.debug "writing new csv data"
      #TODO optomize this so it just merges the new csv data into the existing file, insteading of writing it out again completely
      full_data = csv_read(filename)
      full_data = new_data + full_data
      csv_write(filename, full_data)
      Log.debug "wrote ''#{new_data.length}'' rows of new csv data, for #{full_data.length} total rows of data"

      last_updated_date = full_data[0][:date]
    end


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

  include YahooData
  class TestYahooData < Test::Unit::TestCase
    def xtest_get_current_quote
      q = get_current_quote '^GSPC'

      [
          :date,
          :open,
          :low,
          :high,
          :close,
          :volume,
          :adj_close,
      ].each do |key|
        assert(q.has_key? key)
      end

      puts q.inspect
    end
  end

end