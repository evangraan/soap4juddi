require 'spec_helper'
require 'helpers/test_request'

describe Soap4juddi::Connector do
  before :each do
  	@iut = Soap4juddi::Connector.new
  	@username = 'username'
  	@password = 'password'
		@port = 443
		@hostname = 'localhost'  				
		@base_uri = "http://localhost:#{@port}"
		@service = 'service'
		@action = 'action'  	
  	@test_request = Soap4juddi::TestRequest.new  	
  end

	context "when initialized" do
		it "should be a Soap4juddi::Connector" do
			expect(@iut.is_a?(Soap4juddi::Connector))
		end

		it "should have an XML translator" do
      expect(@iut.soap_xml.is_a?(Soap4juddi::XML)).to eq(true)
		end

		it "should not have any credentials" do
  		expect(@iut.has_credentials?).to eq(false)
		end
	end

  context "when providing credentials for jUDDI authentication" do
  	it "should remember the credentials" do
  		@iut.authenticate(@username, @password)
  		expect(@iut.has_credentials?).to eq(true)
  	end

  	it "should remember credentials if at least a username has been provided" do
  		@iut.authenticate(@username, nil)
  		expect(@iut.has_credentials?).to eq(true)
  	end

  	it "should remember credentials if at least a password has been provided" do
  		@iut.authenticate(nil, @password)
  		expect(@iut.has_credentials?).to eq(true)
  	end

  	it "should not remember credentials if none were provided" do
  		@iut.authenticate(nil, nil)
  		expect(@iut.has_credentials?).to eq(false)
  	end
  end

  context "when using the authentication credentials to obtain an auth token from jUDDI" do
    it "should raise an error InvalidDestinationError with 'no base URI provided' if base URI is nil" do
  		expect {
  		  @iut.authorize(nil)
  	  }.to raise_error(Soap4juddi::InvalidDestinationError, 'no base URI provided')
  	end

    it "should build a jUDDI authorization request using the credentials" do
  		@iut.authenticate(@username, @password)
    	expect(@iut).to receive(:connection).with(@base_uri, 'security', 'get_authToken').and_return(@test_request)
    	expect(@iut.soap_xml).to receive(:element_with_value).with('get_authToken', '', {'userID' => @username, 'cred' => @password})
    	expect{
        @iut.authorize(@base_uri)
      }.to raise_error(NoMethodError)
    end

  	it "should clear an existing auth token" do
  		@iut.auth_token = 'pre-test'
      expect(@iut).to receive(:execute).and_return('authtoken:new-token<')
      @iut.authorize(@base_uri)
      expect(@iut.auth_token).to_not eq('pre-test')
  	end

    it "should extract the auth token from the jUDDI response" do
    	expect(@iut.extract_auth_token('authtoken:new-token<')).to eq('new-token')
    end

    it "should remember the auth token if one was issued" do
      expect(@iut).to receive(:request_auth_token).and_return('new-token')
      @iut.authorize(@base_uri)
      expect(@iut.auth_token).to eq('new-token')    	
    end

    it "should raise an AuthorizationFailed error if the credentials could not produce an auth token" do
    end
  end

  context "when executing a request" do
  	it "should raise an InvalidRequestError error with the message 'no request provided' if the request is nil" do
  		expect {
        @iut.execute(nil)
  		}.to raise_error(Soap4juddi::InvalidRequestError, 'no request provided')
  	end

  	it "should open an HTTP connection and issue the request if a request is provided" do
  		prep_fake_request
  		@iut.execute(@test_request)
  	end

  	it "should return the response body in jsend format" do
  		# sending the actual request with the lambda in connector.rb is tested in the BDD
  		# it is not afforable to test with mocking here and would miss the point
  		# The arrangement below side-steps this lambda and HTTP request calls, focusing
  		# instead on the jsend result
  		prep_fake_request
  		res = @iut.execute(@test_request)
  		expect(res.is_a?(Hash)).to eq(true)
  		expect(res['data'].nil?).to eq(false)
  	end
  end

  context "when creating a connection" do
  	it "should raise an error InvalidDestinationError with 'no base URI provided' if base URI is nil" do
  		expect {
  		  @iut.connection(nil, @service, @action)
  	  }.to raise_error(Soap4juddi::InvalidDestinationError, 'no base URI provided')
  	end

  	it "should raise an error InvalidDestinationError with 'no service provided' if service is nil" do
  		expect {
    		@iut.connection(@base_uri, nil, @action)
  	  }.to raise_error(Soap4juddi::InvalidDestinationError, 'no service provided')
  	end

  	it "should raise an error InvalidDestinationError with 'no action provided' if action is nil" do
  		expect {
    		@iut.connection(@base_uri, @service, nil)
  	  }.to raise_error(Soap4juddi::InvalidDestinationError, 'no action provided')
  	end

    it "should build a URI using the base URI and service" do
  		@iut.connection(@base_uri, @service, @action)
  		expect(@iut.uri.to_s).to eq("http://localhost:443/juddiv3/services/service")
    end

    it "should create a POST request with the uri" do
    	req = @iut.connection(@base_uri, @service, @action)
  		expect(req.is_a?(Net::HTTP::Post)).to eq(true)
  		#expect(req.uri.to_s).to eq("http://localhost:443/juddiv3/services/service")
    end

    it "should set the content type of the request to SOAP" do
    	xml = Soap4juddi::XML.new
    	req = @iut.connection(@base_uri, @service, @action)
  		expect(req["Content-Type"]).to eq(xml.content_type)
    end

    it "should set the soap action to the action provided" do
    	req = @iut.connection(@base_uri, @service, @action)
  		expect(req["SOAPAction"]).to eq('action')
    end
  end

  def prep_fake_request
  	@test_request = Soap4juddi::TestRequest.new
  	@iut.connection(@base_uri, @service, @action)
  	@test_body = Soap4juddi::TestBody.new  		
  	expect(Net::HTTP).to receive(:start).with(@hostname, @port).and_return(@test_body)
  end
end