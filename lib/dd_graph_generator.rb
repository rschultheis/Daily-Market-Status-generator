require 'dd_logger'
require 'dd_csv_io'

require 'gruff'

module DD_GRAPH_GENERATOR

  include CSV_IO
  ROWS_OF_HISTORY_TO_ANALYZE = 20

  INPUT_CSV = "data/technical/^GSPC_analysis.csv"

  def generate_10_day_dma_bands_chart
    raw_data = csv_read(INPUT_CSV, :converter => CSV_IO::YF_READER_CONVERTER, :rows => ROWS_OF_HISTORY_TO_ANALYZE).reverse
    chart_data = {
        :date => raw_data.map { |day| day[:date].strftime('%Y-%m-%d') },
        :adj_close => raw_data.map { |day| day[:adj_close] },

        :short_dma => raw_data.map{ |day| day["20_dma".intern] },
        :mid_dma => raw_data.map{ |day| day["60_dma".intern] },
        :long_dma => raw_data.map{ |day| day["200_dma".intern] },

        :days => ROWS_OF_HISTORY_TO_ANALYZE
    }

    chart = Gruff::Line.new(800)
    chart.title = "S&P 500 - 20 day dma band chart"
    #chart.theme = {
    #  :colors => ['black', 'grey'],
    #  :marker_color => 'grey',
    #  :font_color => 'black',
    #  :background_colors => 'transparent'
    #}

    chart.hide_dots = true
    chart.labels = {
      0 => chart_data[:date][0],
      9 => chart_data[:date][9],
      19 => chart_data[:date][19],
    }
    chart.data("close", chart_data[:adj_close])
    chart.data("20 day dma", chart_data[:short_dma])
    chart.data("60 day dma", chart_data[:mid_dma])
    chart.data("200 day dma", chart_data[:long_dma])

    chart.minimum_value = 1100
    chart.maximum_value = 1400


    output_filename = "output/line_transparent.png"
    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)

  end
end


if __FILE__==$0
  require 'test/unit'

  include DD_GRAPH_GENERATOR

  TEST_FILE_NAME = 'data/technical/^GSPC_analysis.csv'

  class TestDD_GRAPG_GENERATOR < Test::Unit::TestCase
    def test_it
      generate_10_day_dma_bands_chart
    end
  end
end