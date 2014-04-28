require "http2" unless ::Kernel.const_defined?(:Http2)
require "cgi" unless ::Kernel.const_defined?(:CGI)
require "json" unless ::Kernel.const_defined?(:JSON)
require "string-cases" unless ::Kernel.const_defined?(:StringCases)

class GenderizeIoRb
  attr_reader :cache_db
  
  def self.const_missing(name)
    require_relative "../include/#{::StringCases.camel_to_snake(name)}"
    raise LoadError, "Still not defined: '#{name}'." unless ::GenderizeIoRb.const_defined?(name)
    return ::GenderizeIoRb.const_get(name)
  end
  
  INITIALIZE_VALID_ARGS = [:cache_as, :cache_db, :debug]
  def initialize(args = {})
    args.each do |key, val|
      raise "Invalid key: '#{key}'." unless INITIALIZE_VALID_ARGS.include?(key)
    end
    
    @debug = args[:debug]
    @args = args
    @http = Http2.new(:host => "api.genderize.io")
    
    # Make sure the database-version is up-to-date.
    @cache_db = args[:cache_db]
    if @cache_db
      Baza::Revision.new.init_db(:db => @cache_db, :schema => GenderizeIoRb::DatabaseSchema::SCHEMA)
    end
    
    @cache_as = args[:cache_as]
    
    if block_given?
      begin
        yield self
      ensure
        destroy
      end
    end
  end
  
  def info_for_names(names)
    names_lc = names.map{ |name| name.to_s.strip.downcase }
    results = []
    
    if @cache_db
      debug "Looking names up in db: #{names_lc}" if @debug
      @cache_db.select(:genderize_io_rb_cache, :name => names_lc) do |data|
        debug "Found in db-cache: #{data}" if @debug
        
        results << ::GenderizeIoRb::Result.new(
          :data => JSON.parse(data[:result]),
          :genderize_io_rb => self,
          :from_cache_db => true
        )
        
        raise "Could not delete name: #{data[:name]}" unless names_lc.delete(data[:name]) == data[:name]
      end
    end
    
    unless names_lc.empty?
      debug "Looking names up using an HTTP request: #{names_lc}" if @debug
      
      url = "?"
      names_lc.each_with_index do |name, index|
        url << "&" unless url == "?"
        url << "name[#{index}]=#{CGI.escape(name)}"
      end
      
      http_result = @http.get(url)
      json_results = JSON.parse(http_result.body)
      
      json_results.each do |json_result|
        if json_result["gender"] == nil
          error = GenderizeIoRb::Errors::NameNotFound.new("Name was not found on Genderize.io: '#{json_result["name"]}'.")
          error.name = json_result["name"]
          
          results << error
        else
          store_cache_for_name(json_result["name"], json_result)
          
          results << ::GenderizeIoRb::Result.new(
            :data => json_result,
            :genderize_io_rb => self,
            :from_http_request => true
          )
        end
      end
    end
    
    return results
  end
  
  def info_for_name(name)
    name_lc = name.to_s.strip.downcase
    
    # If a database-cache is enabled, try to look result up there first.
    if @cache_db
      cache_db_res = @cache_db.single(:genderize_io_rb_cache, :name => name_lc)
      if cache_db_res
        res = ::GenderizeIoRb::Result.new(
          :data => JSON.parse(cache_db_res[:result]),
          :genderize_io_rb => self,
          :from_cache_db => true
        )
      end
    end
    
    if @cache_as
      cache_as_res = @cache_as.read(cache_key_for_name(name_lc))
      
      if cache_as_res
        res = ::GenderizeIoRb::Result.new(
          :data => JSON.parse(cache_as_res),
          :genderize_io_rb => self,
          :from_cache_as => true
        )
      end
    end
    
    unless res
      http_res = @http.get("?name=#{CGI.escape(name_lc)}")
      json_res = JSON.parse(http_res.body)
      
      raise GenderizeIoRb::Errors::NameNotFound, "Name was not found on Genderize.io: '#{name_lc}'." unless json_res["gender"]
      
      res = ::GenderizeIoRb::Result.new(
        :data => json_res,
        :genderize_io_rb => self,
        :from_http_request => true
      )
      store_cache_for_name(name_lc, json_res)
    end
    
    return res
  end
  
  def destroy
    @http.close
    @destroyed = true
  end
  
  def destroyed?
    return @destroyed
  end
  
private

  def cache_key_for_name(name_lc)
    "genderize_io_rb_#{name_lc}"
  end
  
  def store_cache_for_name(name_lc, json_result)
    debug "Caching name: #{json_result}" if @debug
    
    # Save result to the database cache.
    if @cache_db
      debug "Upserting into cache '#{name_lc}': #{json_result}" if @debug
      @cache_db.upsert(:genderize_io_rb_cache, {:name => name_lc}, {
        :result => JSON.generate(json_result),
        :created_at => Time.now
      })
    end
    
    if @cache_as && !cache_as_res
      @cache_as.write(cache_key_for_name(name_lc), http_res.body)
    end
  end
  
  def debug(str)
    $stderr.puts str if @debug
  end
end
