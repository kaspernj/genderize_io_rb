require "http2" unless ::Kernel.const_defined?(:Http2)
require "cgi" unless ::Kernel.const_defined?(:CGI)
require "json" unless ::Kernel.const_defined?(:JSON)
require "string-cases" unless ::Kernel.const_defined?(:StringCases)

class GenderizeIoRb
  def self.const_missing(name)
    require_relative "../include/#{::StringCases.camel_to_snake(name)}"
    raise LoadError, "Still not defined: '#{name}'." unless ::GenderizeIoRb.const_defined?(name)
    return ::GenderizeIoRb.const_get(name)
  end
  
  def initialize(args = {})
    @args = args
    
    @http = Http2.new(
      :host => "api.genderize.io"
    )
  end
  
  def info_for_name(name)
    res = @http.get("?name=#{CGI.escape(name)}")
    
    return ::GenderizeIoRb::Result.new(
      :data => JSON.parse(res.body),
      :genderize_io_rb => self
    )
  end
  
  def destroy
    @http.close
  end
end
