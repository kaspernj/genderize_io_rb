class GenderizeIoRb::Result
  def initialize(args)
    @args = args
  end
  
  def genderize_io_rb
    return @args[:genderize_io_rb]
  end
  
  def name
    return @args[:data]["name"]
  end
  
  def gender
    return @args[:data]["gender"]
  end
  
  def probability
    return @args[:data]["probability"].to_f
  end
  
  def count
    return @args[:data]["count"].to_i
  end
  
  def to_s
    return "#<GenderizeIoRb::Result::#{@args[:data]}>"
  end
  
  def from_http_request?
    return @args[:from_http_request]
  end
  
  def from_cache_db?
    return @args[:from_cache_db]
  end
end
