#require 'rubygems'
#require 'rspec'
require 'mysql-cellophane.rb'
require 'mysql.rb'

describe MySQLc do
  describe "setup" do
    before(:all) do
      log = File.new('sql_log.log', 'a')
      log.puts "\n\n\n\n\Starting new test iteration"
      log.close
      db = Mysql.real_connect('localhost', 'cello_tester', '', 'cello_test', nil, '/var/run/mysqld/mysqld.sock')
      db.query("DROP TABLE IF EXISTS test_one");
      db.query("CREATE TABLE test_one (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(22) NULL, age INT NULL);")
      db.query("INSERT INTO test_one (name, age) VALUES ('Chris', 26), ('Hayley', 24);")
    end
    it "should setup" do
    end
  end

  it "should assign the correct instance values by default" do 
    db = MySQLc.new
    db.id_field.should be(1)
    db.id.should be(1)
    db.field_list.should eql("*")
  end

  describe "Library" do
    before(:all) do
      @db = MySQLc.new({:socket => '/var/run/mysqld/mysqld.sock', 
                        :user => 'cello_tester', 
                        :password => '', 
                        :database => 'cello_test'})
    end

    it "should escape single quotes" do
      @db.esc("one'two").should eql("one\\'two")
    end

    it "should turn array into escaped quoted string" do
      @db.quoted_string_from([1,"one'two",3]).should eql("'1','one\\'two','3'")
    end

    describe "Extraction Methods" do
      before(:all) do
        @value_array = [1,2,"do';else"]
        @value_string = "'1','2','do\\\';else'"
        @field_array = [:one, :two, :three]
        @field_string = "one,two,three"
        @value_array.size.times do |i|
          @generic_hash ||= {}
          @generic_hash[@field_array[i]] = @value_array[i] 
        end
      end

      it "should extract_values_from a hash" do
        @db.extract_values_from(@generic_hash).should == @value_string
      end

      it "should extract_fields_from a hash" do
        @db.extract_fields_from(@generic_hash).should == @field_string
      end
    end
  end

  describe "SELECT" do
    before do
      @db = MySQLc.new({:socket => '/var/run/mysqld/mysqld.sock', 
                        :user => 'cello_tester', 
                        :password => '', 
                        :database => 'cello_test'})
      @db.table = "test_one"
    end

    it "should get all fields and rows by default" do
      result = @db.select
      result.num_rows.should be 2
      result.num_fields.should be 3
    end

    it "should get only the specified fields" do
      @db.field_list = 'name'
      result = @db.select
      result.num_fields.should be 1
    end

    it "should append extra_cond correctly" do
      @db.extra_cond = "name = '#{@db.esc('Chris')}'"
      result = @db.select
      result.num_rows.should be 1
    end

    it "should allow in-line attribute specification" do
      result = @db.select("test_one", "name, age", "id", "1", "age = '#{@db.esc(26)}'")
      result.num_fields.should be 2
      result.num_rows.should be 1
    end
  end

  describe "INSERT" do
    before(:all) do
      @db = MySQLc.new({:socket => '/var/run/mysqld/mysqld.sock', 
                        :user => 'cello_tester', 
                        :password => '', 
                        :database => 'cello_test'})
      @db.table = "test_one"
      result = @db.select
      @orig_rows = result.num_rows
      @insert_hash = { :name => 'Bobby', :age => '25' }
      @return_hash = { 'name' => 'Bobby', 'age' => '25' }
      @new_id = @db.insert(@insert_hash)
      @db.query = "SELECT * FROM test_one"
      @result = @db.select
    end

    it "should insert a new record" do
      @result.num_rows.should be @orig_rows+1
    end

    it "should insert the correct values and return the newly inserted id" do
      @db.field_list  = 'name, age'
      @db.id_field    = 'id'
      @db.id          = @new_id
      result = @db.select
      result.num_rows.should be 1
      result.fetch_hash.should eql @return_hash
    end

    it "should return the last inserted id" do
      new_id = @db.inserted_id
      @db.field_list = 'id'
      @db.id_field = 1
      @db.id = 1
      @db.extra_cond = '1=1 ORDER BY id DESC LIMIT 1'
      result = @db.select
      max_id = result.fetch_row[0]
      new_id.should eql max_id
    end
  end


  describe "UPDATE" do
    before(:all) do
      @db = MySQLc.new({:socket => '/var/run/mysqld/mysqld.sock', 
                        :user => 'cello_tester', 
                        :password => '', 
                        :database => 'cello_test'})
      @db.table = "test_one"
      @before_rows = @db.select.num_rows
      @db.id_field  = 'id'
      @db.id        = 1
      @db.update({ :name => "Christopher" })
      @db.id_field  = 1
      @db.id        = 1
      @after_rows = @db.select.num_rows
      @result = @db.select.fetch_hash
    end

    it "should not insert a new row" do
      @before_rows.should eql @after_rows
    end

    it "should place the given value(s) into the database" do 
      @result['name'].should eql "Christopher"
    end
  end

  describe "DELETE" do
    before(:all) do
      @db = MySQLc.new({:socket => '/var/run/mysqld/mysqld.sock', 
                        :user => 'cello_tester', 
                        :password => '', 
                        :database => 'cello_test'})
      @db.table = "test_one"

    end

    it "should remove a single row when conditions only match one row" do
      before_count = @db.select.num_rows
      new_id = @db.insert({ :name => "Temp Guy", :age => 30 })
      @db.id_field = 'id'
      @db.id = new_id
      @db.delete
      @db.id_field = 1
      @db.id = 1
      after_count = @db.select.num_rows
      before_count.should be after_count
    end

    it "should remove multiple rows when conditions match multiple rows" do
      @db.insert({ :name => "Temp Guy", :age => 30 })
      @db.insert({ :name => "Temp Guy", :age => 30 })
      before_results= @db.select
      @db.id_field = 'name'
      @db.id = "Temp Guy"
      @db.delete
      @db.id_field = 1
      @db.id = 1
      after_results = @db.select
      before_results.num_rows.should be(after_results.num_rows+2)
    end
  end

  describe "COUNT" do
    before(:all) do
      @db = MySQLc.new({:socket => '/var/run/mysqld/mysqld.sock', 
                        :user => 'cello_tester', 
                        :password => '', 
                        :database => 'cello_test'})
      @db.table = "test_one"
    end

    it "should return 0 when no rows match the criteria" do
      @db.id_field = 'name'
      @db.id = "Roger"
      @db.count.should be 0
    end

    it "should return 1 when only one row matches condition" do
      @db.id_field = 'id'
      @db.id = 1
      @db.count.should be 1
    end

    it "should return an integer of the count of the matching rows" do
      @db.insert({ :name => "Temp Guy", :age => 30 })
      @db.insert({ :name => "Temp Guy", :age => 30 })
      @db.id_field = 'name'
      @db.id = "Temp Guy"
      @db.count.should be 2
    end
  end
end
