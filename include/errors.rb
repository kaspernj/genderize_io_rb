class GenderizeIoRb::Errors
  class NameNotFound < RuntimeError
    attr_accessor :name
  end
end
