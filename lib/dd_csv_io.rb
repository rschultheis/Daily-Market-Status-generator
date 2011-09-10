require 'date'
require 'dd_logger'
require 'csv'
require 'csv-mapper'
require 'ohash'

#For handling the reading and writing to csv files
module CSV_IO
  include CsvMapper

  #CSV CONVERTER PROCS
  #These blocks will be used to transform csv string values into the appropriate object types (Dates, numbers)
  #And from the objects back into strings for writing back to csv
  #The transformation of data types is handled by the CSV_IO module by default, using the converter option to specify these blocks as seen below
  YF_READER_CONVERTER= lambda do |unconverted_string|
    case unconverted_string
      #date column is YYYY-MM-DD, like '2011-08-09'
      when /^\d{4}-\d{2}-\d{2}$/
        Date.strptime(unconverted_string, '%Y-%m-%d')

      #this is the way dates come from yahoo.finance.quote yql source, mm/dd/yyyy
      when /^\d{1,2}\/\d{1,2}\/\d{4}$/
        Date.strptime(unconverted_string, '%m/%d/%Y')

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
    opts = {
        :converter => CSV_IO::YF_READER_CONVERTER
    }.merge(opts)
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

  #This returns the data in a format that is useful for generating graphs
  # The return is a hash, each key is a column, each value is an array of all values for that column/key
  def csv_read_arrays filename, opts={}
    opts = {
        :reverse => true
    }.merge(opts)

    raw_data = csv_read(filename, opts)

    raw_data.reverse! if opts.has_key?(:reverse) && opts[:reverse]

    columns_to_get = opts.has_key?(:columns) ? opts[:columns] : raw_data[0].keys

    hash_of_arrays = Hash.new
    hash_of_arrays[:length] = raw_data.length
    columns_to_get.each do |column|
      hash_of_arrays[column] = raw_data.map do |row|
        case row[column]
          when Date
            row[column].strftime('%Y-%m-%d')
          else
            row[column]
        end

      end
    end
    hash_of_arrays
  end

  def csv_write filename, contents, opts={}
    opts = {
        :converter => CSV_IO::YF_WRITER_CONVERTER
    }.merge(opts)
    if File.exist? filename
      Log.warn "Deleting existing '#{filename}'"
      File.delete(filename)
    end

    raise "Unsupported class for contents parameter '#{contents.class}'" unless [Array].include?(contents.class)

    CSV.open(filename, 'w') do |csv|
      #headers
      headers = contents[0].keys
      header_length = headers.length
      csv << headers

      contents.each do |row|
        #ensure this row's headers match the first rows headers
        unless ((row.keys[0,header_length] == headers) || (row.keys == headers[0, row.keys.length]))
          raise "This row's headers do not line up with first row's headers:\nFIRST ROW: #{headers}\nTHIS ROW:  #{row.keys[0,header_length]}"
        end

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
