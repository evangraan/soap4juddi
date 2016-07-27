require 'helpers/test_response'

module Soap4juddi
  class TestConnector
    attr_reader :base_uri
    attr_reader :version
    attr_reader :action
    attr_reader :body
    attr_accessor :response

    def request_soap(base_uri, version, action, body, &block)
      @base_uri = base_uri
      @version = version
      @action = action
      @body = body      
      block.call(Soap4juddi::TestResponse.new(@response))
    end
  end
end