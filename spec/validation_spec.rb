# encoding: utf-8
require File.expand_path('spec_helper.rb', File.dirname(__FILE__))
include CassandraCQL

describe "Validation Roundtrip tests" do
  before(:each) do
    @connection = setup_cassandra_connection
  end

  def create_and_fetch_column(column_family, value)
    @connection.execute("insert into #{column_family} (id, test_column) values (?, ?)", 'test', value)
    res = @connection.execute("select test_column from #{column_family} where id = ?", 'test')
    return res.fetch[0]
  end

  def create_column_family(name, test_column_type, opts="")
    if !@connection.schema.column_family_names.include?(name)
      @connection.execute("CREATE COLUMNFAMILY #{name} (id text PRIMARY KEY, test_column #{test_column_type}) #{opts}")
    end
  end

  context "with ascii validation" do
    let(:cf_name) { "validation_cf_ascii" }
    before(:each) { create_column_family(cf_name, 'ascii') }

    it "should return an ascii string" do
      create_and_fetch_column(cf_name, "test string").should eq("test string")
    end
  end

  context "with bigint validation" do
    let(:cf_name) { "validation_cf_bigint" }
    before(:each) { create_column_family(cf_name, 'bigint') }

    def test_for_value(value)
      create_and_fetch_column(cf_name, value).should eq(value)
      create_and_fetch_column(cf_name, value*-1).should eq(value*-1)
    end
  
    it "should properly convert integer values that fit into 1 byte" do
      test_for_value(1)
    end
    it "should properly convert integer values that fit into 2 bytes" do
      test_for_value(2**8 + 80)
    end
    it "should properly convert integer values that fit into 3 bytes" do
      test_for_value(2**16 + 622)
    end
    it "should properly convert integer values that fit into 4 bytes" do
      test_for_value(2**24 + 45820)
    end
    it "should properly convert integer values that fit into 5 bytes" do
      test_for_value(2**32 + 618387)
    end
  end

  context "with blob validation" do
    let(:cf_name) { "validation_cf_blob" }
    before(:each) { create_column_family(cf_name, 'blob') }

    it "should return a blob" do
      bytes = "binary\x00"
      bytes = bytes.force_encoding('ASCII-8BIT') if RUBY_VERSION >= "1.9"
      create_and_fetch_column(cf_name, bytes).should eq(bytes)
    end
  end

  context "with boolean validation" do
    let(:cf_name) { "validation_cf_boolean" }
    before(:each) { create_column_family(cf_name, 'boolean') }

    it "should return true" do
      create_and_fetch_column(cf_name, true).should be_true
    end

    it "should return false" do
      create_and_fetch_column(cf_name, false).should be_false
    end
  end

  context "with counter validation" do
    let(:cf_name) { "validation_cf_counter" }
    before(:each) {
      if !@connection.schema.column_family_names.include?(cf_name)
        @connection.execute("CREATE COLUMNFAMILY #{cf_name} (id text PRIMARY KEY) WITH default_validation=CounterColumnType")
      end
      @connection.execute("TRUNCATE #{cf_name}")
    }

    it "should increment a few times" do
      10.times do |i|
        @connection.execute("UPDATE #{cf_name} SET test=test + 1 WHERE id=?", 'test_key')
        @connection.execute("SELECT test FROM #{cf_name} WHERE id=?", 'test_key').fetch[0].should eq(i+1)
      end
    end

    it "should decrement a few times" do
      10.times do |i|
        @connection.execute("UPDATE #{cf_name} SET test=test - 1 WHERE id=?", 'test_key')
        @connection.execute("SELECT test FROM #{cf_name} WHERE id=?", 'test_key').fetch[0].should eq((i+1)*-1)
      end
    end
  end

  context "with decimal validation" do
    let(:cf_name) { "validation_cf_decimal" }
    before(:each) { create_column_family(cf_name, 'decimal') }

    def test_for_value(value)
      create_and_fetch_column(cf_name, value).should eq(value)
      create_and_fetch_column(cf_name, value*-1).should eq(value*-1)
    end
  
    it "should return a small decimal" do
      test_for_value(15.333)
    end
    it "should return a huge decimal" do
      test_for_value(BigDecimal.new('129182739481237481341234123411.1029348102934810293481039'))
    end
  end

  context "with double validation" do
    let(:cf_name) { "validation_cf_double" }
    before(:each) { create_column_family(cf_name, 'double') }

    def test_for_value(value)
      create_and_fetch_column(cf_name, value).should be_within(0.1).of(value)
      create_and_fetch_column(cf_name, value*-1).should be_within(0.1).of(-1*value)
    end
  
    it "should properly convert some float values" do
      test_for_value(1.125)
      test_for_value(384.125)
      test_for_value(65540.125)
      test_for_value(16777217.125)
      test_for_value(1099511627776.125)
    end
  end

  context "with float validation" do
    let(:cf_name) { "validation_cf_float" }
    before(:each) { create_column_family(cf_name, 'float') }

    def test_for_value(value)
      create_and_fetch_column(cf_name, value*-1).should eq(value*-1)
      create_and_fetch_column(cf_name, value).should eq(value)
    end
  
    it "should properly convert some float values" do
      test_for_value(1.125)
      test_for_value(384.125)
      test_for_value(65540.125)
    end
  end

  context "with int validation" do
    let(:cf_name) { "validation_cf_int" }
    before(:each) { create_column_family(cf_name, 'int') }

    def test_for_value(value)
      create_and_fetch_column(cf_name, value).should eq(value)
      create_and_fetch_column(cf_name, value*-1).should eq(value*-1)
    end
  
    it "should properly convert integer values that fit into 1 byte" do
      test_for_value(1)
    end
    it "should properly convert integer values that fit into 2 bytes" do
      test_for_value(2**8 + 80)
    end
    it "should properly convert integer values that fit into 3 bytes" do
      test_for_value(2**16 + 622)
    end
    it "should properly convert integer values that fit into 4 bytes" do
      test_for_value(2**24 + 45820)
    end
  end

  context "with text validation" do
    let(:cf_name) { "validation_cf_text" }
    before(:each) { create_column_family(cf_name, 'varchar') }

    it "should return a non-multibyte string" do
      create_and_fetch_column(cf_name, "snark").should eq("snark")
    end

    it "should return a multibyte string" do
      if RUBY_VERSION >= "1.9"
        create_and_fetch_column(cf_name, "sn\xC3\xA5rk".force_encoding('UTF-8')).should eq("sn\xC3\xA5rk".force_encoding('UTF-8'))
      else
        create_and_fetch_column(cf_name, "snårk").should eq("snårk")
      end
    end
  end

  context "with timestamp validation" do
    let(:cf_name) { "validation_cf_timestamp" }
    before(:each) { create_column_family(cf_name, 'timestamp') }

    it "should return a timestamp" do
      ts = Time.new
      res = create_and_fetch_column(cf_name, ts)
      res.to_f.should be_within(0.001).of(ts.to_f)
      res.class.should eq(Time)
    end

    it "should return a timestamp given a date" do
      date = Date.today
      res = create_and_fetch_column(cf_name, date)
      [:year, :month, :day].each do |sym|
        res.send(sym).should eq(date.send(sym))
      end
      res.class.should eq(Time)
    end
  end

  context "with uuid validation" do
    let(:cf_name) { "validation_cf_uuid" }
    before(:each) { create_column_family(cf_name, 'uuid') }

    it "should return a uuid" do
      uuid = UUID.new
      create_and_fetch_column(cf_name, uuid).should eq(uuid)
    end
  end

  context "with varchar validation" do
    let(:cf_name) { "validation_cf_varchar" }
    before(:each) { create_column_family(cf_name, 'varchar') }

    it "should return a non-multibyte string" do
      create_and_fetch_column(cf_name, "snark").should eq("snark")
    end

    it "should return a multibyte string" do
      create_and_fetch_column(cf_name, "snårk").should eq("snårk")
    end
  end

  context "with varint validation" do
    let(:cf_name) { "validation_cf_varint" }
    before(:each) { create_column_family(cf_name, 'varint') }

    def test_for_value(value)
      create_and_fetch_column(cf_name, value).should eq(value)
      create_and_fetch_column(cf_name, value*-1).should eq(value*-1)
    end
  
    it "should properly convert integer values that fit into 1 byte" do
      test_for_value(1)
    end
    it "should properly convert integer values that fit into 2 bytes" do
      test_for_value(2**8 + 80)
    end
    it "should properly convert integer values that fit into 3 bytes" do
      test_for_value(2**16 + 622)
    end
    it "should properly convert integer values that fit into more than 8 bytes" do
      test_for_value(2**256)
    end
  end
end