require 'dd_logger'
require 'dd_csv_io'

#require 'rmagick'
require 'gruff'

module DD_GRAPH_GENERATOR

  include CSV_IO

  include Magick

  def set_min_max_values chart
    #set the min / max to next lowest 100, next highest 100
    chart.minimum_value = chart.minimum_value - (chart.minimum_value % 100)
    chart.maximum_value = chart.maximum_value - (chart.maximum_value % 100) + 100

  end

  def set_theme chart
    chart.theme = {
      :colors => ['yellow', 'white', 'blue', 'red'],
      :marker_color => 'white',
      :font_color => 'black',
      :background_colors => '#C5C5C5'
    }
  end

  def set_date_labels chart, chart_data
    num_days = chart_data[:length]
    chart.labels = {
      0 => chart_data[:date][0],
      (num_days/2) => chart_data[:date][num_days/2],
      (num_days-1) => chart_data[:date][num_days-1],
    }
  end

  def generate_dma_chart input_filename, output_filename, opts={}
    opts = {
      :dma_periods => [200, 60, 20],
      :days => 20,
      :image_size => 800,
      :blob => false,
    }.merge(opts)

    opts[:dma_period_keys] = opts[:dma_periods].map { |p| "#{p}_dma".intern }

    chart_data = get_chart_data(input_filename, :rows => opts[:days], :columns => [:date, :adj_close] + opts[:dma_period_keys ])

    chart = Gruff::Line.new(opts[:image_size])

    chart.data("close", chart_data[:adj_close])
    chart.data("20 day dma", chart_data[opts[:dma_period_keys][2]])
    chart.data("60 day dma", chart_data[opts[:dma_period_keys][1]])
    chart.data("200 day dma", chart_data[opts[:dma_period_keys][0]])

    set_min_max_values(chart)

    chart.title = "S&P 500 - 20 day dma band chart"
    set_theme(chart)
    set_date_labels chart, chart_data
    chart.hide_dots = true
    if opts[:blob]
      return chart.to_blob
    end
    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)
  end

  def generate_dma_band_chart input_filename, output_filename, opts={}
    opts = {
      :dma_period => 200,
      :days => 200,
      :image_size => '800x500',
    }.merge(opts)

    dma_key           = "#{opts[:dma_period]}_dma".intern
    dma_top_band_key  = "#{opts[:dma_period]}_dma_top_band".intern
    dma_bot_band_key  = "#{opts[:dma_period]}_dma_bot_band".intern

    chart_data = get_chart_data(input_filename, :rows =>opts[:days], :columns => [:date, :adj_close, dma_key, dma_top_band_key, dma_bot_band_key])

    chart = Gruff::Line.new(opts[:image_size])

    chart.data("close", chart_data[:adj_close])
    chart.data("200 day dma", chart_data[dma_key])
    chart.data("top dma band", chart_data[dma_top_band_key])
    chart.data("bottom dma band", chart_data[dma_bot_band_key])

    set_min_max_values(chart)

    chart.title = "S&P 500 - #{opts[:dma_period]} day dma band chart - #{chart_data[:length]} days"
    set_theme(chart)
    chart.hide_dots = true
    chart.hide_legend = true
    set_date_labels chart, chart_data
    Log.debug "writing chart to '#{output_filename}'"
    chart.write(output_filename)
    output_filename
  end

  def generate_volume_chart input_filename, output_filename, opts={}
    opts = {
      :avg_volume_key   => :"20_vma",
      :days             => 20,
      :image_size       => "800x300",
      :hide_title       => true,
      :blob             => false,
    }.merge(opts)

    chart_data = get_chart_data input_filename, :rows=>opts[:days], :columns=>[:date, :volume, opts[:avg_volume_key]]
    num_days = chart_data[:length]

    chart = Gruff::Bar.new(opts[:image_size])

    chart_data[:volume_avg_ratio] = []
    (0...chart_data[:length]).each do |row|
#      chart_data[:volume_avg_diff] << chart_data[:"20_vma"][row] - chart_data[:volume][row]
      chart_data[:volume_avg_ratio] << (((chart_data[:volume][row] - chart_data[opts[:avg_volume_key]][row]) / chart_data[opts[:avg_volume_key]][row]) * 100.0).to_i
    end

    chart.data("Vol ratio", chart_data[:volume_avg_ratio])

    chart.maximum_value = 50
    chart.minimum_value = -50
    chart.y_axis_increment = 25

    chart.title = "Volume Avg ratio for past #{num_days} days"
    chart.hide_title = opts[:hide_title]
    set_theme(chart)
    #set_date_labels chart, chart_data
    chart.hide_legend = true
    if opts[:blob]
      return chart.to_blob
    end
    Log.debug "writing volume chart to '#{output_filename}'"
    chart.write(output_filename)
  end

  def generate_composite input_filename, output_filename, opts={}
    opts = {
     :days => 20,
    }.merge(opts)

    dma_blob =      generate_dma_chart    input_filename, 'x', :blob => true, :days => opts[:days]
    dma_graph = Image.from_blob(dma_blob)[0]
    volume_blob =   generate_volume_chart input_filename, 'x', :blob => true, :days => opts[:days], :hide_title => true
    volume_graph =  Image.from_blob(volume_blob)[0]

    volume_graph = volume_graph.crop(0,40, volume_graph.columns, volume_graph.rows-80 )

    columns = dma_graph.columns + 20
    rows = dma_graph.rows + volume_graph.rows + 25

    combined = Image.new(columns, rows) { self.background_color = 'gray' }

    combined.composite!(dma_graph, 10, 10, OverCompositeOp)
    combined.composite!(volume_graph, 10, 12 + dma_graph.rows, OverCompositeOp)

    Log.debug "writing composite graph to #{output_filename}"
    combined.write(output_filename)

  end
end


if __FILE__==$0
  require 'test/unit'
  require 'fileutils'

  include DD_GRAPH_GENERATOR

  TEST_INPUT_FILENAME = 'lib/test_data/technical/^GSPC_analysis.csv'
  TEST_OUTPUT_DIR = "lib/test_output/imgs"
  #delete all the image files in the test output dir
  FileUtils.mkdir_p TEST_OUTPUT_DIR
  Dir["#{TEST_OUTPUT_DIR}/**/*.png"].each do |old_img|
    Log.info "Deleting #{old_img}"
    File.delete old_img
  end

  class TestDD_GRAPG_GENERATOR < Test::Unit::TestCase

    def xtest_dma_chart
      assert_nothing_raised {generate_dma_chart TEST_INPUT_FILENAME, File.join(TEST_OUTPUT_DIR, "test_dma.png"), :days => 200}
    end
    def xtest_dma_band_chart
      assert_nothing_raised {generate_dma_band_chart TEST_INPUT_FILENAME, File.join(TEST_OUTPUT_DIR, "test_dma_band.png"), :dma_period => 200, :days => 200}
    end

    def xtest_volume_chart
      assert_nothing_raised { generate_volume_chart(TEST_INPUT_FILENAME, File.join(TEST_OUTPUT_DIR, "test_bar_chart.png"), :days => 100)}
    end

    def test_generate_composite
      generate_composite(TEST_INPUT_FILENAME, File.join(TEST_OUTPUT_DIR, "test_composite.png"))

    end
  end
end