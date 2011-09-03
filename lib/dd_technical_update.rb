require 'dd_logger'
require 'dd_csv_io'

class Array
  def sum
    inject(0.0) { |result, el| result + el }
  end

  def mean
    sum / size
  end
end

module DD_Updater

  include CSV_IO

  #6 years base data
  ROWS_OF_HISTORY_TO_ANALYZE = 400
  #1 year to prime
  PRIMER_ROWS = 200
  #leaves 5 years data that will be analyzed

  #configure what moving averages and volume average periods to keep
  DMA_PERIODS = [200, 60, 20]
  VMA_PERIODS = [200, 60, 20]

  DMA_BAND = 0.05
  VMA_BAND = 0.25


  def update_technical_analysis_csv filename
    #Dir.mkdir(File.dirname(filename), 'technical')
    ta_filename = File.join(File.dirname(filename), 'technical', "#{filename.match(/([A-Z^]+)\.csv$/)[1]}_analysis.csv")

    historical_data = csv_read(filename, :converter => CSV_IO::YF_READER_CONVERTER, :rows => ROWS_OF_HISTORY_TO_ANALYZE).reverse

    ((PRIMER_ROWS)...historical_data.length).each do |row|

      historical_data[row][:close_pct_diff] = ((historical_data[row][:adj_close] / historical_data[row-1][:adj_close]) - 1.0) * 100.0

      DMA_PERIODS.each do |dma_period|
        dma = historical_data[(row-dma_period)...row].map{|hsh| hsh[:adj_close]}.mean
        top_band = dma + (dma * DMA_BAND)
        bot_band = dma - (dma * DMA_BAND)
        historical_data[row]["#{dma_period}_dma".intern] = dma
        historical_data[row]["#{dma_period}_dma_pct_diff".intern] = ((historical_data[row][:adj_close] / dma) - 1.0) * 100.0
        historical_data[row]["#{dma_period}_dma_top_band".intern] = top_band
        historical_data[row]["#{dma_period}_dma_bot_band".intern] = bot_band
      end
      VMA_PERIODS.each do |vma_period|
        vma = historical_data[(row-vma_period)...row].map{|hsh| hsh[:volume]}.mean
        top_band = vma + (vma * DMA_BAND)
        bot_band = vma - (vma * DMA_BAND)
        historical_data[row]["#{vma_period}_vma".intern] = vma
        historical_data[row]["#{vma_period}_vma_pct_diff".intern] = ((historical_data[row][:volume] / vma) - 1.0) * 100.0
        historical_data[row]["#{vma_period}_vma_top_band".intern] = top_band
        historical_data[row]["#{vma_period}_vma_bot_band".intern] = bot_band
      end

      Log.debug "row: #{historical_data[row]}"
    end

    Log.debug "writing analysis to '#{ta_filename}'"
    csv_write(ta_filename, historical_data.reverse, :converter => CSV_IO::YF_WRITER_CONVERTER )

  end


  def update_technical_datas
    glob_str = File.join('data', "*.csv")
    data_files = Dir.glob(glob_str)
    Log.error "No csv files found in '#{glob_str}'"
    data_files.each do |data_file|
      symbol = data_file.match(/([A-Z^]+)\.csv$/)[1]
      Log.debug "Updating symbol '#{symbol}' into file '#{data_file}'"
      update_technical_analysis_csv data_file
    end
  end

end


if __FILE__ == $0
  require 'test/unit'

  include DD_Updater

  TEST_CSV = 'lib/test_data/^GSPC.csv'

  class TestDDUpdater < Test::Unit::TestCase
    def test_technical_update
      #update_technical_analysis_csv TEST_CSV
      update_technical_datas
    end
  end
end
