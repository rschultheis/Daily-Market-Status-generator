require 'dd_logger'
require 'dd_csv_io'
require 'dd_graph_generator'

require 'erb'

BASE_DIR = Dir.pwd
#csv files
RAW_DATA_DIR = File.join(BASE_DIR ,'data')
TECHNICAL_DATA_DIR = File.join(RAW_DATA_DIR, 'technical')

module DD_HTML_Builder

  include CSV_IO
  ROWS_OF_HISTORY_TO_ANALYZE = 1

  include DD_GRAPH_GENERATOR

  def chart name, type
    filename = "#{name}_#{type}.png"
    Log.info "Generating chart: '#{filename}'"

    case type
      when '200_dma_band_chart'
         generate_dma_band_chart File.join(TECHNICAL_DATA_DIR, "^#{name.upcase}_analysis.csv" ), File.join('output', filename), :dma_period => 200, :chart_days => 1000
    end

    "<img width='800' height='400' src='#{filename}'></img>"
  end

  def generate_daily_dose_html input_file, template_filename, output_dir
    data = csv_read(input_file, :rows => ROWS_OF_HISTORY_TO_ANALYZE)

    #pull out some stuff for the template:
    @current_day_numbers = data[0]
    @current_day_numbers.each_pair do |k,v|
      Log.debug "current_day_numbers key: '#{k}'\t-> '#{v}'"
    end

    #execute template!
    template_str = IO.read(template_filename)

    #Log.debug "pre-executed template:\n#{template_str}"

    template = ERB.new(template_str)
    blog_html = template.result(binding)

    Log.debug "post-executed template\n\n#{blog_html}\n"

    output_filename = File.join(output_dir, File.basename(template_filename).sub(/\.erb$/i, ''))
    Log.debug "writing html to '#{output_filename}'"
    File.open(output_filename, 'w') {|f| f.write(blog_html) }

  end
end


if __FILE__==$0
  require 'test/unit'

  include DD_HTML_Builder

  TEST_FILE_NAME = 'lib/test_data/technical/^GSPC_analysis.csv'
  TEST_TEMPLATE_NAME = File.join('lib', 'test_templates', 'example.html.erb')
  TEST_OUTPUT_DIR = 'lib/test_output'

  class TestDD_HTML_Builder < Test::Unit::TestCase
    def test_it
      generate_daily_dose_html TEST_FILE_NAME, TEST_TEMPLATE_NAME, TEST_OUTPUT_DIR
    end
  end
end
