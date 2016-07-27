module Soap4juddi
  class TestResponse
    attr_accessor :body

    def initialize(body)
      @body = body
    end
  end
end