module Soap4juddi
  class TestBody
    def body
      "response"
    end
  end

  class TestRequest
    attr_accessor :response
    attr_accessor :content_type
    attr_accessor :action
    attr_accessor :body

    def start(_hostname, _port) 
      @response
    end
  end
end