require 'dd_logger'
require 'dd_csv_io'

require 'erb'

module DD_HTML_Builder

  include CSV_IO
  ROWS_OF_HISTORY_TO_ANALYZE = 1

  def generate_daily_dose_html filename, template_filename='example.erb'
    data = csv_read(filename, :rows => ROWS_OF_HISTORY_TO_ANALYZE)

    #pull out some stuff for the template:
    @current_day_numbers = data[0]
    Log.debug @current_day_numbers.keys

    #execute template!
    template_str = IO.read(File.join('templates', template_filename))

    Log.debug "pre-executed template:\n#{template_str}"

    template = ERB.new(template_str)
    blog_html = template.result(binding)

    Log.debug "post-executed template\n#{blog_html}"



    output_filename = File.join('output', File.basename(template_filename) + '.html')
    Log.debug "writing html to '#{output_filename}'"
    File.open(output_filename, 'w') {|f| f.write(blog_html) }

  end
end


if __FILE__==$0
  require 'test/unit'

  include DD_HTML_Builder

  TEST_FILE_NAME = 'data/technical/^GSPC_analysis.csv'

  class TestDD_HTML_Builder < Test::Unit::TestCase
    def test_it
      generate_daily_dose_html TEST_FILE_NAME
    end
  end
end