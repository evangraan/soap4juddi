require 'net/http'
require 'jsender'

module Soap4juddi
  class Connector
    include Jsender

    attr_reader :uri
    attr_reader :soap_xml
    attr_accessor :auth_token

    def initialize
      @soap_xml = Soap4juddi::XML.new
    end

    def has_credentials?
      return true if @auth_user or @auth_password
      false
    end

    def authenticate(auth_user, auth_password)
       @auth_user = auth_user
       @auth_password =auth_password
    end

    def authorize(base_uri)
      validate_base_uri(base_uri)
      @auth_token = '' #clear existing auth token
      @auth_token = request_auth_token(base_uri)
    end

    def request_soap(base_uri, version, service, request, attr = nil, &block)
      req = connection(base_uri, version, service)
      req.body = @soap_xml.soap_envelope(request, service, attr)
      execute(req) do |res|
        block.call(res)
      end
    end  

    def execute(req, &block)
      validate_destination(req)
      res = Net::HTTP.start(@uri.hostname, @uri.port) do |http|
        http.request(req)
      end
      jsend_result(res, block)
    end

    def connection(base_uri, service, action)
      validate_connection_parameters(base_uri, service, action)
      build_post_request(base_uri, service, action)
    end      

    def extract_auth_token(body)
      (body.split('authtoken:')[1]).split('<')[0]
    end

    private

    def request_auth_token(base_uri)
      result = execute(build_authorization_request(base_uri)) do |res|
         @auth_token = extract_auth_token(res.body)
       end
       @auth_token
    end

    def build_authorization_request(base_uri)
      req = connection(base_uri, 'security', 'get_authToken')
      auth = @soap_xml.element_with_value('get_authToken', '', {'userID' => @auth_user, 'cred' => @auth_password})
      req.body = @soap_xml.envelope_header_body(auth)
      req
    end

    def jsend_result(res, block)
      case res
        when Net::HTTPSuccess
          return soap_success(res, block)
        else
          return fail(res.body)
        end       
    end

    def soap_success(res, block)
      result = block.call(res) if block
      return success_data(result) if result
      return success
    end  

    def build_uri(base_uri, service)
      @uri = URI("#{base_uri}/juddiv3/services/#{service}")
      @uri.request_uri
    end

    def validate_connection_parameters(base_uri, service, action)
      validate_base_uri(base_uri)
      raise Soap4juddi::InvalidDestinationError.new('no service provided') if service.nil?
      raise Soap4juddi::InvalidDestinationError.new('no action provided') if action.nil?
      true
    end

    def build_post_request(base_uri, service, action)
      req = Net::HTTP::Post.new(build_uri(base_uri, service))
      req.content_type = @soap_xml.content_type
      req['SOAPAction'] = action
      req
    end

    def validate_destination(req)
      raise Soap4juddi::InvalidRequestError.new('no request provided') if req.nil?
      true
    end

    def validate_base_uri(base_uri)
      raise Soap4juddi::InvalidDestinationError.new('no base URI provided') if base_uri.nil?
      true
    end
  end
end
