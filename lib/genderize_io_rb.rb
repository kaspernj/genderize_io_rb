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
  
  INITIALIZE_VALID_ARGS = [:cache_as, :cache_db]
  def initialize(args = {})
    args.each do |key, val|
      raise "Invalid key: '#{key}'." unless INITIALIZE_VALID_ARGS.include?(key)
    end
    
    @args = args
    @http = Http2.new(:host => "api.genderize.io")
    
    # Make sure the database-version is up-to-date.
    @cache_db = args[:cache_db]
    if @cache_db
      Baza::Revision.new.init_db(:db => @cache_db, :schema => GenderizeIoRb::DatabaseSchema::SCHEMA)
    end
    
    @cache_as = args[:cache_as]
  end
  
  def info_for_name(name, args = {})
    name = name.to_s.strip
    name_lc = name.downcase
    
    # If a database-cache is enabled, try to look result up there first.
    if @cache_db
      cache_db_res = @cache_db.single(:genderize_io_rb_cache, {:name => name_lc})
      if cache_db_res
        res = ::GenderizeIoRb::Result.new(
          :data => JSON.parse(cache_db_res[:result]),
          :genderize_io_rb => self
        )
      end
    end
    
    cache_as_key = "genderize_io_rb_#{name_lc}"
    if @cache_as
      cache_as_res = @cache_as.read(cache_as_key)
      
      if cache_as_res
        res = ::GenderizeIoRb::Result.new(
          :data => JSON.parse(cache_as_res),
          :genderize_io_rb => self
        )
      end
    end
    
    unless res
      http_res = @http.get("?name=#{CGI.escape(name)}")
      json_res = JSON.parse(http_res.body)
      
      raise GenderizeIoRb::Errors::NameNotFound, "Name was not found on Genderize.io: '#{name}'." unless json_res["gender"]
      
      res = ::GenderizeIoRb::Result.new(
        :data => json_res,
        :genderize_io_rb => self
      )
    end
    
    # Save result to the database cache.
    if @cache_db && !cache_db_res
      @cache_db.insert(:genderize_io_rb_cache, {
        :name => name_lc,
        :result => http_res.body,
        :created_at => Time.now
      })
    end
    
    if @cache_as && !cache_as_res
      @cache_as.write(cache_as_key, http_res.body)
    end
    
    return {:result => res, :cache_db => @cache_db_res, :cache_as => cache_as_res}
  end
  
  def destroy
    @http.close
  end
end
