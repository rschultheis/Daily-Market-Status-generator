require 'date'
require 'dd_logger'
require 'csv'
require 'csv-mapper'
require 'ohash'

#For handling the reading and writing to csv files
module CSV_IO
  include CsvMapper

  #YF_READER_CONVERTER= [:date, :float, :float, :float, :float, :integer, :float]
  YF_READER_CONVERTER= lambda do |unconverted_string|
    case unconverted_string
      #date column is YYYY-MM-DD, like '2011-08-09'
      when /^\d{4}-\d{2}-\d{2}$/
        Date.strptime(unconverted_string, '%Y-%m-%d')

      #open, high, low, close, adj_close
      when /^\d+\.\d+$/
        unconverted_string.to_f

      #volume
      when /^\d+$/
        unconverted_string.to_i

        #shouldn't happen, but just in case..
      else
        unconverted_string
    end
  end

  YF_WRITER_CONVERTER = lambda do |value|
    case value
      when Date
        value.strftime('%Y-%m-%d')

      when Float
        sprintf('%.2f', value)

      else
        value.to_s

    end
  end


  def csv_read filename, opts={}
    Log.debug "reading csv file #{filename} with options #{opts}"
    raise "No such file #{filename}" unless File.exist? filename

    #use CsvMapper.import over import b/c rake conflicts with import method
    CsvMapper.import filename do

      #deal with any options that were supplied
      opts.each_pair do |opt_key, opt_value|
        case opt_key
          #rows options specifies a limit on rows to read
          when :rows
            stop_at_row opt_value

          when :converter
            parser_options :converters => opt_value

        end
      end

      #putting the rows into OpenHash objects solves problems in Struct and OpenStructs
      # we can easily tell what is in the object using keys (hard with OStruct), and we can easily dynamically add new members (hard with Struct)
      map_to OpenHash
      read_attributes_from_file
    end
  end

  def csv_write filename, contents, opts={}
    if File.exist? filename
      Log.warn "Deleting existing '#{filename}'"
      File.delete(filename)
    end

    raise "Unsupported class for contents parameter '#{contents.class}'" unless [Array].include?(contents.class)

    CSV.open(filename, 'w') do |csv|
      #headers
      csv << contents[0].keys

      contents.each do |row|
        if opts.has_key? :converter
          csv << row.values.map{ |value| opts[:converter].call value }
        else
          csv << row.values
        end
      end


    end
    Log.debug "Done writing to '#{filename}'"
  end

end


#test code
if (__FILE__ == $0)
  require 'test/unit'

  include CSV_IO
  #data/config used by tests
  READ_TEST_CSV = 'lib/csv_test_files/test_read.csv'
  TEST_CSV_HEADERS = [:date, :open, :high, :low, :close, :volume, :adj_close]

  #used to test mapping to appropriate field type
  TEST_CSV_FIELD_CONVERTER = YF_READER_CONVERTER
  TEST_CSV_WRITER_CONVERTER = YF_WRITER_CONVERTER

  SHOULD_BE_KLASS_EXPR = /^Should_be_(\S+)s$/
  Should_be_Floats = [:open, :high, :low, :close, :adj_close]
  Should_be_Bignums = [:volume]
  Should_be_Dates = [:date]

  class CSV_IO_READ_TESTS < Test::Unit::TestCase

    def test_open_csv_file
      #read the csv, assert that no exceptions raised
      csv_data = nil
      assert_nothing_raised {csv_data = csv_read READ_TEST_CSV}
      #csv should have exactly 1000 rows, the file is 1001 lines inlcuding the header
      assert_equal(1000, csv_data.length)


      #test the :rows option
      assert_nothing_raised {csv_data = csv_read READ_TEST_CSV, :rows => 1 }
      #csv should have exactly 1000 rows, the file is 1001 lines inlcuding the header
      assert_equal(1, csv_data.length)

      #test the :rows option
      assert_nothing_raised {csv_data = csv_read READ_TEST_CSV, :rows => 400 }
      #csv should have exactly 1000 rows, the file is 1001 lines inlcuding the header
      assert_equal(400, csv_data.length)

    end

    def test_map_field_types

      csv_data = nil
      assert_nothing_raised {csv_data = csv_read READ_TEST_CSV, :rows => 10, :converter => TEST_CSV_FIELD_CONVERTER }
      #test the headers are as expected
      assert_equal(TEST_CSV_HEADERS, csv_data[0].keys)

      #test that each field is mapped to it's correct type, do this based on constants starting with Should_be_
      CSV_IO_READ_TESTS.constants.select {|con| con =~ SHOULD_BE_KLASS_EXPR}.each do |field_list_const|
        expected_klass = field_list_const.to_s.match(SHOULD_BE_KLASS_EXPR)[1]
        field_list = CSV_IO_READ_TESTS.const_get(field_list_const)
        field_list.each do |field|
          Log.debug "checking that '#{field}' is a '#{expected_klass}': #{csv_data[0][field].inspect}"
          assert_equal(expected_klass, csv_data[0][field].class.to_s)
        end
      end

    end

  end

  class CSV_IO_WRITE_TESTS < Test::Unit::TestCase

    def test_csv_writing
      csv_orig_data = csv_read READ_TEST_CSV, :rows => 400

      test_out_filename = "lib/csv_test_files/test_out.csv"
      assert_nothing_raised { csv_write test_out_filename, csv_orig_data }
      assert(File.exist?(test_out_filename))

      csv_new_data = csv_read test_out_filename


      assert_equal(csv_orig_data.length, csv_new_data.length)
      assert_equal(csv_orig_data[0].members, csv_new_data[0].members)
      assert_equal(csv_orig_data[0].values, csv_new_data[0].values)

      (0...10).each do |row|
        TEST_CSV_HEADERS.each do |field|
          Log.debug "checking field '#{field}': #{csv_orig_data[row][field]} == #{csv_new_data[row][field]}"
          assert_equal(csv_orig_data[row][field], csv_new_data[row][field])
        end
      end

    end

    def test_csv_formatted_writing
      csv_orig_data = csv_read READ_TEST_CSV, :rows => 400, :converter => TEST_CSV_FIELD_CONVERTER

      test_out_filename = "lib/csv_test_files/test_out.csv"
      assert_nothing_raised { csv_write test_out_filename, csv_orig_data, :converter => TEST_CSV_WRITER_CONVERTER }
      assert(File.exist?(test_out_filename))

      csv_new_data = csv_read test_out_filename, :converter => TEST_CSV_FIELD_CONVERTER


      assert_equal(csv_orig_data.length, csv_new_data.length)
      assert_equal(csv_orig_data[0].members, csv_new_data[0].members)
      assert_equal(csv_orig_data[0].values, csv_new_data[0].values)

      (0...10).each do |row|
        TEST_CSV_HEADERS.each do |field|
          Log.debug "checking field '#{field}': #{csv_orig_data[row][field]} == #{csv_new_data[row][field]}"
          assert_equal(csv_orig_data[row][field], csv_new_data[row][field])
        end
      end

    end

  end
end
