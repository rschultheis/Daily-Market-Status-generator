require 'dd_logger'
require 'dd_csv_io'

require 'gruff'

module DD_GRAPH_GENERATOR

  include CSV_IO

  def generate_dma_chart input_filename, output_filename, opts={
      :dma_periods => [200, 60, 20],
      :chart_days => 20,
      :image_size => 800,
    }

    opts[:dma_period_keys] = opts[:dma_periods].map { |p| "#{p}_dma".intern }

    chart_data = csv_read_arrays(input_filename, :rows => opts[:chart_days], :columns => [:date, :adj_close] + opts[:dma_period_keys ])

    chart = Gruff::Line.new(opts[:image_size])
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
    chart.data("20 day dma", chart_data[opts[:dma_period_keys][2]])
    chart.data("60 day dma", chart_data[opts[:dma_period_keys][1]])
    chart.data("200 day dma", chart_data[opts[:dma_period_keys][0]])

    chart.minimum_value = 1100
    chart.maximum_value = 1400


    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)

  end

  def generate_dma_band_chart input_filename, output_filename, opts={
      :dma_period => 200,
      :chart_days => 200,
      :image_size => 800,
    }

    dma_key           = "#{opts[:dma_period]}_dma".intern
    dma_top_band_key  = "#{opts[:dma_period]}_dma_top_band".intern
    dma_bot_band_key  = "#{opts[:dma_period]}_dma_bot_band".intern

    chart_data = csv_read_arrays(input_filename, :rows =>opts[:chart_days], :columns => [:date, :adj_close, dma_key, dma_top_band_key, dma_bot_band_key])
    num_days = chart_data[:length]

    chart = Gruff::Line.new(opts[:image_size])
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
    chart.data("200 day dma", chart_data[dma_key])
    chart.data("top dma band", chart_data[dma_top_band_key])
    chart.data("bottom dma band", chart_data[dma_bot_band_key])

    #chart.y_axis_increment = 100.0

    #chart.minimum_value = chart.minimum_value * 0.90
    chart.minimum_value = chart.minimum_value - (chart.minimum_value % 100)
    #chart.maximum_value = chart.maximum_value * 1.10
    chart.maximum_value = chart.maximum_value - (chart.maximum_value % 100) + 100

    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)

  end

end


if __FILE__==$0
  require 'test/unit'

  include DD_GRAPH_GENERATOR

  TEST_INPUT_FILENAME = 'lib/test_data/technical/^GSPC_analysis.csv'
  TEST_OUTPUT_FILENAME= "lib/test_output/imgs/gspc_20_day_dma_band.png"


  class TestDD_GRAPG_GENERATOR < Test::Unit::TestCase
    def test_it
      generate_dma_chart TEST_INPUT_FILENAME, TEST_OUTPUT_FILENAME
    end
  end
end