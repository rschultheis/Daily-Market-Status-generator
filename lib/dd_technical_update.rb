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


  def update_technical_analysis_csv input_filename, output_filename

    historical_data = csv_read(input_filename, :converter => CSV_IO::YF_READER_CONVERTER, :rows => ROWS_OF_HISTORY_TO_ANALYZE).reverse

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

    Log.debug "writing analysis to '#{output_filename}'"
    csv_write(output_filename, historical_data.reverse, :converter => CSV_IO::YF_WRITER_CONVERTER )

  end
end


if __FILE__ == $0
  require 'test/unit'

  include DD_Updater

  TEST_INPUT_FILE = 'lib/test_data/^GSPC.csv'
  TEST_OUTPUT_FILE = 'lib/test_data/technical/^GSPC_analysis.csv'

  class TestDDUpdater < Test::Unit::TestCase
    def test_technical_update
      update_technical_analysis_csv TEST_INPUT_FILE, TEST_OUTPUT_FILE
    end
  end
end
