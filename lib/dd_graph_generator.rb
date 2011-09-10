require 'dd_logger'
require 'dd_csv_io'

require 'gruff'

module DD_GRAPH_GENERATOR

  include CSV_IO

  def set_min_max_values chart
    #set the min / max to next lowest 100, next highest 100
    chart.minimum_value = chart.minimum_value - (chart.minimum_value % 100)
    chart.maximum_value = chart.maximum_value - (chart.maximum_value % 100) + 100

  end

  def generate_dma_chart input_filename, output_filename, opts={
      :dma_periods => [200, 60, 20],
      :chart_days => 20,
      :image_size => 800,
    }

    opts[:dma_period_keys] = opts[:dma_periods].map { |p| "#{p}_dma".intern }

    chart_data = get_chart_data(input_filename, :rows => opts[:chart_days], :columns => [:date, :adj_close] + opts[:dma_period_keys ])

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

     set_min_max_values(chart)

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

    chart_data = get_chart_data(input_filename, :rows =>opts[:chart_days], :columns => [:date, :adj_close, dma_key, dma_top_band_key, dma_bot_band_key])
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

     set_min_max_values(chart)

    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)

  end

  def generate_volume_chart input_filename, output_filename, opts={
      :avg_volume_key => :"20_vma",
      :days => 20,
      :image_size => 800,
    }

    chart_data = get_chart_data input_filename, :rows=>opts[:days], :columns=>[:date, :volume, opts[:avg_volume_key]]
    num_days = chart_data[:length]

    chart = Gruff::Bar.new(opts[:image_size])

    chart_data[:volume_avg_ratio] = []
    (0...chart_data[:length]).each do |row|
#      chart_data[:volume_avg_diff] << chart_data[:"20_vma"][row] - chart_data[:volume][row]
      chart_data[:volume_avg_ratio] << (((chart_data[:volume][row] - chart_data[opts[:avg_volume_key]][row]) / chart_data[opts[:avg_volume_key]][row]) * 100.0).to_i
    end

    #chart.data("Volume", chart_data[:volume])
    #chart.data("Vol diff", chart_data[:volume_avg_diff])
    chart.data("Vol ratio", chart_data[:volume_avg_ratio])

    chart.maximum_value = 50
    chart.minimum_value = -50
    chart.y_axis_increment = 25

    chart.labels = {
      1 => chart_data[:date][1],
      (num_days/2) => chart_data[:date][num_days/2],
      (num_days-2) => chart_data[:date][num_days-2],
    }
    chart.hide_legend = true
    chart.title = "Volume Avg ratio for past #{num_days} days"

    Log.debug "writing volume chart to '#{output_filename}'"
    chart.write(output_filename)
  end
end


if __FILE__==$0
  require 'test/unit'

  include DD_GRAPH_GENERATOR

  TEST_INPUT_FILENAME = 'lib/test_data/technical/^GSPC_analysis.csv'
  TEST_OUTPUT_DIR = "lib/test_output/imgs"


  class TestDD_GRAPG_GENERATOR < Test::Unit::TestCase
    def xtest_dma_chart
      assert_nothing_raised {generate_dma_chart TEST_INPUT_FILENAME, File.join(TEST_OUTPUT_DIR, "gspc_20_day_dma_band.png")}
    end

    def test_volume_chart
      assert_nothing_raised { generate_volume_chart TEST_INPUT_FILENAME, File.join(TEST_OUTPUT_DIR, "test_bar_chart.png") }
    end
  end
end