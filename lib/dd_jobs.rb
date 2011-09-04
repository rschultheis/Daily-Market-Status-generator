require 'dd_logger'

module DD_JOBS

  BASE_DIR = Dir.pwd
  #csv files
  RAW_DATA_DIR = File.join(BASE_DIR ,'data')
  TECHNICAL_DATA_DIR = File.join(RAW_DATA_DIR, 'technical')

  #html template directory
  TEMPLATE_DIR = File.join(BASE_DIR, 'templates')

  #output locatons for html and .png files
  OUTPUT_DIR = File.join(BASE_DIR, 'output')
  GRAPH_OUTPUT_DIR = File.join(OUTPUT_DIR, 'imgs')

  #log the config
  constants.each {|c|
    dir = const_get(c)
    Log.debug "Job Config: #{c.to_s} = '#{dir}'"
    if (c =~ /_DIR$/) && not(Dir.exist?(dir))
      Log.warn "directory does not exist, creating it"
      Dir.mkdir(dir)
    end
  }


  require 'dd_historical_update'
  require 'dd_technical_update'
  include DD_Updater

  def update_historical_data_folder

    glob_str = File.join(RAW_DATA_DIR, "*.csv")
    data_files = Dir[glob_str]

    Log.error "No csv files found in '#{glob_str}'" unless data_files.length > 0
    data_files.each do |data_file|
      symbol = data_file.match(/([A-Z^]+)\.csv$/)[1]
      Log.debug "Updating symbol '#{symbol}' into file '#{data_file}'"
      update_historical_csv symbol, data_file
    end
  end

  def update_technical_data_folder

    glob_str = File.join(RAW_DATA_DIR, "*.csv")
    data_files = Dir[glob_str]

    Log.error "No csv files found in '#{glob_str}'" unless data_files.length > 0
    data_files.each do |input_file|
      symbol = input_file.match(/([A-Z^]+)\.csv$/)[1]

      output_file = File.join(TECHNICAL_DATA_DIR, "#{input_file.match(/([A-Z^]+)\.csv$/)[1]}_analysis.csv")

      Log.debug "Updating symbol '#{symbol}'\n\tinput file='#{input_file}'\n\toutput file='#{output_file}'"
      update_technical_analysis_csv input_file, output_file
    end
  end

  ##GRAPHICS
  require 'dd_graph_generator'
  include DD_GRAPH_GENERATOR

  GRAPH_INPUT_DATA = File.join(TECHNICAL_DATA_DIR, '^GSPC_analysis.csv' )
  GRAPH_OUTPUT_FILE = File.join(GRAPH_OUTPUT_DIR, 'gspc_20_day_dma_band.png')
  def make_graphics
    generate_10_day_dma_bands_chart GRAPH_INPUT_DATA, GRAPH_OUTPUT_FILE
  end


  ## HTML FILES

  require 'dd_build_html'
  include DD_HTML_Builder
  BLOG_INPUT_DATA = File.join(TECHNICAL_DATA_DIR, '^GSPC_analysis.csv' )
  BLOG_TEMPLATE_NAME = File.join('lib', 'test_templates', 'example.erb')

  def update_html_files
    generate_daily_dose_html BLOG_INPUT_DATA, BLOG_TEMPLATE_NAME, OUTPUT_DIR
  end
end

#test code
if __FILE__==$0
  require 'test/unit'

  include DD_JOBS

  class TestDD_Jobs <Test::Unit::TestCase
    def xtest_update_historical_data_folder
      assert_nothing_raised {
        update_historical_data_folder
      }
    end

    def xtest_update_technical_data_folder
      assert_nothing_raised {
        update_technical_data_folder
      }
    end

    def test_create_graphics
      make_graphics
    end

    def xtest_update_html
      update_html_files
    end
  end

end

