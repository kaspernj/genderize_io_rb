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
  
  def initialize(args = {})
    @args = args
    @http = Http2.new(:host => "api.genderize.io")
    
    # Make sure the database-version is up-to-date.
    @cache_db = args[:cache_db]
    if @cache_db
      Baza::Revision.new.init_db(:db => @cache_db, :schema => GenderizeIoRb::DatabaseSchema::SCHEMA)
    end
  end
  
  def info_for_name(name)
    name = name.to_s.strip
    name_lc = name.downcase
    
    # If a database-cache is enabled, try to look result up there first.
    if @cache_db
      res = @cache_db.single(:genderize_io_rb_cache, {:name => name_lc})
      if res
        return ::GenderizeIoRb::Result.new(
          :data => JSON.parse(res[:result]),
          :genderize_io_rb => self
        )
      end
    end
    
    http_res = @http.get("?name=#{CGI.escape(name)}")
    
    res = ::GenderizeIoRb::Result.new(
      :data => JSON.parse(http_res.body),
      :genderize_io_rb => self
    )
    
    # Save result to the database cache.
    if @cache_db
      @cache_db.insert(:genderize_io_rb_cache, {
        :name => name_lc,
        :result => http_res.body,
        :created_at => Time.now
      }) unless @cache_db.single(:genderize_io_rb_cache, {:name => name_lc})
    end
    
    return res
  end
  
  def destroy
    @http.close
  end
end
