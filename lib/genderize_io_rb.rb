require "http2" unless ::Kernel.const_defined?(:Http2)
require "cgi" unless ::Kernel.const_defined?(:CGI)
require "json" unless ::Kernel.const_defined?(:JSON) && defined?(:JSON::Parser)
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
  
  def info_for_name(name)
    name, name_lc = regularize_name(name)
    
    # If a database-cache is enabled, try to look result up there first.
    if @cache_db
      cache_db_res = @cache_db.single(:genderize_io_rb_cache, {:name => name_lc})
      if cache_db_res
        res = parse_gender_io_result(cache_db_res)
      end
    end
    
    cache_as_key = "genderize_io_rb_#{name_lc}"
    if @cache_as
      cache_as_res = @cache_as.read(cache_as_key)
      puts "CacheAsRes: #{cache_as_res}"
      
      if cache_as_res
        res = parse_gender_io_result(cache_db_res)
      end
    end
    
    res, http_res = get_gender_io(name) unless res
    
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
    
    return ::GenderizeIoRb::ActiveSupportCacheResult.new({
      :result => res, 
      :cache_db => @cache_db_res, 
      :cache_as => cache_as_res
    })
  end
  
  def destroy
    @http.close
  end
  
  private
  
  def regularize_name(name)
    case name 
      when String
        [name.to_s.strip, name.downcase]
      when Array
        [name.map { |n| n.to_s.strip }, name_lc = name.to_s.downcase]
      else
        raise GenderizeIoRb::Errors::NameParseError, "Name could not be parsed: '#{name}'."
      end
  end
  
  def get_gender_io(name)
    http_res = case name
      when String
        @http.get("?name=#{CGI.escape(name)}")
      when Array
        @http.get("?" + name.each_with_index.map { |name, index| "name[#{index}]=#{CGI.escape(name)}" }.join("&"))
      else
        raise GenderizeIoRb::Errors::NameParseError, "Name could not be parsed: '#{name}'."
      end
          
    res = parse_gender_io_result(http_res.body)
    
    [res, http_res]    
  end
  
  def parse_gender_io_result(http_res) 
    json_res = JSON.parse(http_res)
    case json_res
      when Hash
        raise GenderizeIoRb::Errors::NameNotFound, "Name was not found on Genderize.io: '#{json_res["name"]}'." unless json_res["gender"]
        ::GenderizeIoRb::Result.new(
          :data => json_res,
          :genderize_io_rb => self
        )
      when Array
        json_res.map do |res|
          warn "Name was not found on Genderize.io: '#{res["name"]}'." unless res["gender"]
          ::GenderizeIoRb::Result.new(
            :data => res,
            :genderize_io_rb => self 
          )  
        end       
      else
        raise GenderizeIoRb::Errors::ResponseParseError, "Response could not be parsed: '#{json_res}'." 
      end   
  end
end
