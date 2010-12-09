# MySQL-cellophane is a very thin wrapper around the Mysql Ruby implementation
# MySQc provides an API interface for those famaliar with SQL 
# and wishes to have more fine grained control over their
# queries, but don't want to write each query manually.
#
# Author:: Chris Marshall (mailto:chris@chrismar035.com)
#
# :title:MySQL-Cellophane

class MySQLc
  #require 'rubygems'
  require 'mysql'
  
  attr_accessor :table, :field_list, :id_field, :id, :extra_cond,
    :result, :query

  # initializes common instance variables.
  #
  # can setup connection, but does not create connection
  def initialize(options = {})
    log = File.new('sql_log.log', 'a')
    log.puts "Created New MySQLc instance"
    log.close

    options[:host]      ||= 'localhost'
    options[:user]      ||= 'root'
    options[:password]  ||= 'secure'
    options[:database]  ||= 'test'
    options[:port]      ||= nil
    options[:socket]    ||= nil
    options[:flag]      ||= nil

    @options = {}
    @options.merge!(options)

    @field_list = "*"
    @id_field   = 1
    @id         = 1
    @cache      = {}
  end

  # takes hash of connection ooptions, has default also
  # sets @db as Mysql instance
  #
  # as separate method for lazy connection
  def connect(options = {})
    @options.merge(options)

    @db = Mysql.connect(@options[:host], @options[:user], @options[:password], @options[:database],
                         @options[:port], @options[:socket], @options[:flag])
  end

  # builds query from parts if neccessary
  #
  # returns cached result if exists
  #
  # saves result in @result
  def execute
    log = File.new('sql_log.log', 'a')
    log.puts "Before: #{@query}"
    log.close
    build_query if(@query.nil?) 

    query = @query # keep local copy of query string
    @query = nil #prevent same queries from running more than once without rebuilding

    #print "#{query}\n"
    #if(@cache[query].nil? && use_cache)
      connect if @db.nil? #connect to the database if needs be

      log = File.new('sql_log.log', 'a')
      log.puts "To Execute: #{query}"
      log.close
      @result = @db.query(query) # run query
      log = File.new('sql_log.log', 'a')
      log.puts "After: #{@query}"
      log.close
      @cache[query] = @result # save result to cache hash

    #else
      #@result = @cache[query]
    #end
  end

  # Creates the internal query string for 
  # processing. Shouldn't ever NEED to be used externally.
  def build_query(update = false)
    @query = ""
    if @id_field != ""
      @query += "WHERE #{esc @id_field} = '#{esc @id}'"
    end

    if @extra_cond != "" && !@extra_cond.nil?
      @query += ((@query == "") ? " WHERE " : " AND ") + @extra_cond
    end

    @query = "SELECT #{field_list} FROM #{@table} #{@query}"
  end


  # sets instance attributes from fucntion parameters
  # called by each public API methods
  def set_attributes(*vals)
    # when vals gets strung along from another *vals, the original 
    # empty array becomes the first element of the new vals
    # so, we need to pull the first element off and work on that
    vals = vals[0] if vals[0].class.to_s == 'Array'

    if vals.size >= 1 && vals[0] != "" 
      @table      = vals[0] if vals.size >= 1
      @field_list = vals[1] unless vals.size < 2
      @id_field   = vals[2] unless vals.size < 3
      @id         = vals[3] unless vals.size < 4
      @extra_cond = vals[4] unless vals.size < 5
    end
  end

  # creates a select query and returns the reqult 
  # as Mysql::Result
  #
  # takes an optional last parameter of a hash.
  # This hash has symbol keys of any/all of the following:
  # table, field_list, id_field, id, extra_cond
  def select(*vals)
    #print "#{vals}\n"
    set_attributes vals 
    execute
  end

  # inserts a new row into the table 
  # from the given hash
  #
  #  { :column_one_field => 'column_one_value', 
  #  :column_two_field => 'column_two_value' }
  #
  # return the newly insertted row's ID
  #
  # takes an optional last parameter of a hash.
  # This hash has symbol keys of any/all of the following:
  # table, field_list, id_field, id, extra_cond
  def insert(inserts, *vals)
    set_attributes vals

    fields = extract_fields_from inserts 
    values = extract_values_from inserts 


    @query = "INSERT INTO #{esc(@table)} (#{fields}) VALUES " +
      "(#{values})"
    execute
    inserted_id
  end

  # returns the last inserted ID
  def inserted_id
    @query = "SELECT LAST_INSERT_ID();"
    execute
    @result.fetch_row[0]
  end

  # takes a given hash: 
  #
  #  { :column_one_field => 'column_one_value', :column_two_field => 'column_two_value' }
  #
  # and updates the correct row
  #
  # takes an optional last parameter of a hash.
  # This hash has symbol keys of any/all of the following:
  # table, field_list, id_field, id, extra_cond
  def update(updates, *vals)
    set_attributes vals
    
    sets = updates.map {|key,val| "#{key} = '#{esc(val)}'"}

    @query = ""
    if @id_field != ""
      @query += "WHERE #{@id_field} = #{@id}"
    end

    if @extra_cond != "" && !@extra_cond.nil?
      @query += ((@query == "") ? " WHERE " : " AND ") + @extra_cond
    end

    @query = "UPDATE #{@table} SET #{sets.join ','} " + @query
    execute
  end

  # deletes row(s) matching the instalce variables'
  # criteria
  #
  # takes an optional last parameter of a hash.
  # This hash has symbol keys of any/all of the following:
  # table, field_list, id_field, id, extra_cond
  def delete(*vals)
    set_attributes vals

    @query = ""
    if @id_field != ""
      @query += "WHERE #{esc @id_field} = '#{esc @id}'"
    end

    if @extra_cond != "" && !@extra_cond.nil?
      @query += ((@query == "") ? " WHERE " : " AND ") + @extra_cond
    end

    @query = "DELETE FROM #{@table} #{@query}"
    execute
  end

  # returns an integer of the totals returned by query
  #
  # takes an optional last parameter of a hash.
  # This hash has symbol keys of any/all of the following:
  # table, field_list, id_field, id, extra_cond
  def count(*vals)
    set_attributes vals

    result = execute
    result.num_rows
  end

  # library function to convert values
  # in a hash (or plain array) into an
  # escaped single quoted comma
  # delimited string
  #
  # i.e.
  #   { :key => 'val1', :key2 => "val'2" }  #=> "'val1','val\'2'"
  #   [ 'val1', "val'2" ]                   #=> "'val1', 'val\'2'"
  def quoted_string_from hash_or_array
    array =  hash_or_array.class == Hash ? hash_or_array.values : hash_or_array
    array.collect { |raw| "'#{esc(raw)}'"}.join(',')
  end

  # takes a hash and returns a songle 
  # quoted string of the values
  #   
  #   { :key => 'val1', :key2 => "val'2" }  #=> "'val1','val\'2'"
  def extract_values_from hash
    quoted_string_from hash
  end

  # takes a hash and returns a
  # comma separated list of keys
  #
  #   { :key1 => 'val1', :key2 => 'key2' } #=> "key1, key2"
  def extract_fields_from hash
    hash.keys.join(',')
  end


  # takes string parameter and 
  # returns saftely escaped string
  def esc(raw_string)
    connect if @db.nil? #connect to the database if needs be

    @db.quote(raw_string.to_s)
  end

end

