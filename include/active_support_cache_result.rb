require "delegate"

class GenderizeIoRb::ActiveSupportCacheResult < SimpleDelegator
  VALID_ACCESSORS = [:result, :cache_db, :cache_as]
  VALID_ACCESSORS.each do |name|
    define_method(name) do
      __send__("[]", name)
    end
  end
end

