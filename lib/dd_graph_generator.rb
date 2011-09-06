require 'dd_logger'
require 'dd_csv_io'

require 'gruff'

module DD_GRAPH_GENERATOR

  include CSV_IO

  def generate_10_day_dma_bands_chart input_filename, output_filename
    raw_data = csv_read(input_filename, :converter => CSV_IO::YF_READER_CONVERTER, :rows => 20).reverse
    chart_data = {
        :date => raw_data.map { |day| day[:date].strftime('%Y-%m-%d') },
        :adj_close => raw_data.map { |day| day[:adj_close] },

        :short_dma => raw_data.map{ |day| day["20_dma".intern] },
        :mid_dma => raw_data.map{ |day| day["60_dma".intern] },
        :long_dma => raw_data.map{ |day| day["200_dma".intern] },
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


    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)

  end

  def generate_dma_band_chart input_filename, output_filename, opts={
      :dma_period => 200,
      :chart_days => 200,
  }

    raw_data = csv_read(input_filename, :converter => CSV_IO::YF_READER_CONVERTER, :rows => opts[:chart_days]).reverse
    num_days = raw_data.length
    chart_data = {
        :date => raw_data.map { |day| day[:date].strftime('%Y-%m-%d') },
        :adj_close => raw_data.map { |day| day[:adj_close] },

        :dma => raw_data.map{ |day| day["#{opts[:dma_period]}_dma".intern] },
        :dma_top_band => raw_data.map{ |day| day["#{opts[:dma_period]}_dma_top_band".intern] },
        :dma_bot_band => raw_data.map{ |day| day["#{opts[:dma_period]}_dma_bot_band".intern] },
    }

    chart = Gruff::Line.new(800)
    chart.title = "S&P 500 - #{opts[:dma_period]} day dma band chart - #{num_days} days"
    chart.theme = {
      :colors => ['yellow', 'white', 'blue', 'red'],
      :marker_color => 'white',
      :font_color => 'black',
      :background_colors => '#C5C5C5'
    }

    chart.hide_dots = true
    chart.hide_legend = true

    chart.labels = {
      0 => chart_data[:date][0],
      (num_days/2) => chart_data[:date][num_days/2],
      (num_days-1) => chart_data[:date][num_days-1],
    }
    chart.data("close", chart_data[:adj_close])
    chart.data("200 day dma", chart_data[:dma])
    chart.data("top dma band", chart_data[:dma_top_band])
    chart.data("bottom dma band", chart_data[:dma_bot_band])

    #chart.y_axis_increment = 100.0

    #chart.minimum_value = chart.minimum_value * 0.90
    chart.minimum_value = chart.minimum_value - (chart.minimum_value % 100)
    #chart.maximum_value = chart.maximum_value * 1.10
    chart.maximum_value = chart.maximum_value - (chart.maximum_value % 100) + 100

    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)

  end

  def generate_200_dma_band_chart input_filename, output_filename
    generate_dma_band_chart input_filename, output_filename, :dma_period => 200, :chart_days => 1000
  end

end


if __FILE__==$0
  require 'test/unit'

  include DD_GRAPH_GENERATOR

  TEST_INPUT_FILENAME = 'lib/test_data/technical/^GSPC_analysis.csv'
  TEST_OUTPUT_FILENAME= "lib/test_output/imgs/gspc_20_day_dma_band.png"


  class TestDD_GRAPG_GENERATOR < Test::Unit::TestCase
    def test_it
      generate_10_day_dma_bands_chart TEST_INPUT_FILENAME, TEST_OUTPUT_FILENAME
    end
  end
end