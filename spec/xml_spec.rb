require 'spec_helper'

describe Soap4juddi::XML do
  before :each do
  	@iut = Soap4juddi::XML.new
  	@element = 'element'
  	@key = 'key'
  	@value = 'value'
  	@attributes = { 'attr1' => 'value 1', 'attr2' => 'value 2'}
  	@well_formed = "<urn:element attr1='value 1' attr2='value 2'>value</urn:element>"
  	@no_attributes = "<urn:element>value</urn:element>"
  	@one_attribute = "<urn:element attr1='value 1'>value</urn:element>"
  	@no_value = "<urn:element attr1='value 1' attr2='value 2'></urn:element>"
  end

  context "when building xml for an element with a value, potentially with attributes" do
  	it "should produce an xml opening tag '<urn'" do
      expect(@iut.element_with_value(@element, @value, @attributes).include?('<urn')).to eq(true)  
  	end

  	it "should produce an xml closing tag '/urn>'" do
      expect(@iut.element_with_value(@element, @value, @attributes).include?('</urn')).to eq(true)  
  	end

  	it "should name the xml tag according to the element provided" do
      expect(@iut.element_with_value(@element, @value, @attributes).include?('<urn:element')).to eq(true)  
      expect(@iut.element_with_value(@element, @value, @attributes).include?('</urn:element>')).to eq(true)  
  	end

  	it "should indicate the value provided as the value of the xml tag" do
      expect(@iut.element_with_value(@element, @value, @attributes).include?('>value<')).to eq(true)  
  	end

  	it "should not produce any attributes in the tag if none were provided" do
      expect(@iut.element_with_value(@element, @value)).to eq(@no_attributes)  
  	end

  	it "should produce one attribute in the tag separated from the key by a space if one attribute is provided" do
      expect(@iut.element_with_value(@element, @value, { 'attr1' => 'value 1'})).to eq(@one_attribute)  
  	end

  	it "should produce multiple attributes in the tag seperated from the key and one another by spaces if multiple attributes are provided" do
      expect(@iut.element_with_value(@element, @value, @attributes)).to eq(@well_formed)  
  	end

  	it "should produce an empty value indication if no value is provided" do
      expect(@iut.element_with_value(@element, nil, @attributes)).to eq(@no_value)  
      expect(@iut.element_with_value(@element, '', @attributes)).to eq(@no_value)  
  	end

  	it "should raise an error InvalidElementError with 'invalid element provided' if no element is provided" do
  	  expect {
        @iut.element_with_value(nil, @value, @attributes)
  	  }.to raise_error(Soap4juddi::InvalidElementError, 'invalid element provided')
  	end

  	it "should raise an error InvalidElementError with 'no element provided' if an empty element is provided" do
  	  expect {
        @iut.element_with_value('', @value, @attributes)
  	  }.to raise_error(Soap4juddi::InvalidElementError, 'no element provided')
  	end

  	it "should raise an error InvalidElementError with 'no element provided' if an all spaces element is provided" do
  	  expect {
        @iut.element_with_value('   ', @value, @attributes)
  	  }.to raise_error(Soap4juddi::InvalidElementError, 'no element provided')
  	end

  	it "should raise an error InvalidElementError with 'invalid element provided' if the element provided is not a string" do
  	  expect {
        @iut.element_with_value(5, @value, @attributes)
  	  }.to raise_error(Soap4juddi::InvalidElementError, 'invalid element provided')
  	end

  	it "should produce well-formed xml with all the properties included" do
      expect(@iut.element_with_value(@element, @value, @attributes)).to eq(@well_formed)  
  	end
  end

  context "when building xml for an element with a key-value value, potentially with attributes" do
  	it "should use element_with_value with the value set to 'key=value'" do
  		expect(@iut).to receive(:element_with_value).with(@element, 'key:value', @attributes)
  		@iut.element_with_key_value(@element, @key, @value, @attributes)
  	end
  end

  context "when given soap text and a key, extract a value from the key" do
    it "raise an error InvalidTextError with 'no key provided' if the key is nil" do
      expect {
        @iut.extract_value("some soap key  = value fdsjklf", nil)
      }.to raise_error(Soap4juddi::InvalidTextError, 'no key provided')
    end

    it "raise an error InvalidTextError with 'invalid key provided' if the key is empty" do
      expect {
        @iut.extract_value("some soap key  = value fdsjklf", '')
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid key provided')
    end

    it "raise an error InvalidTextError with 'invalid key provided' if the key is only spaces" do
      expect {
        @iut.extract_value('some soap key  = value fdsjklf', '   ')
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid key provided')
    end

    it "raise an error InvalidTextError with 'invalid key provided' if the key is not a string" do
      expect {
        @iut.extract_value('some soap key  = value fdsjklf', 5)
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid key provided')
    end

    it "raise an error InvalidTextError with 'no text provided' if the soap text is nil" do
      expect {
        @iut.extract_value(nil, 'key')
      }.to raise_error(Soap4juddi::InvalidTextError, 'no text provided')
    end

    it "raise an error InvalidTextError with 'invalid text provided' if the soap text is empty" do
      expect {
        @iut.extract_value('', 'key')
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid text provided')
    end

    it "raise an error InvalidTextError with 'invalid text provided' if the soap text is only spaces" do
      expect {
        @iut.extract_value('   ', 'key')
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid text provided')
    end

    it "raise an error InvalidTextError with 'invalid text provided' if the soap text is not a string" do
      expect {
        @iut.extract_value(5, 'key')
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid text provided')
    end

    it "should return nil if the key is not in the soap text" do
      expect(@iut.extract_value('some soap key  = value fdsjklf', 'key2')).to eq(nil)
    end

    it "should return nil if the key is not followed by an equal sign in the soap text" do
        expect(@iut.extract_value('some soap key  "value" fdsjklf', 'key')).to eq(nil)
    end

    it "should return nil if the value is not surrounded by quites in the soap text" do
        expect(@iut.extract_value('some soap key  value fdsjklf', 'key')).to eq(nil)
    end

    it "should extract the value from the key=value string in the soap text, regardless of quite type around the value" do
        expect(@iut.extract_value('some soap key="value" fdsjklf', 'key')).to eq('value')
        expect(@iut.extract_value("some soap key='value' fdsjklf", 'key')).to eq('value')
    end

    it "should extract the value from the key=value string in the soap text" do
        expect(@iut.extract_value('some soap key="value" fdsjklf', 'key')).to eq('value')
    end

    it "should extract the value even if the equal sign is wrapped in an arbitrary number of spaces" do
        expect(@iut.extract_value('some soap key =  "value" fdsjklf', 'key')).to eq('value')
    end
  end

  context "when wrapping a body in a soap header" do
    it "should treat the body as empty if it is nil" do
      expect(@iut.envelope_header_body(nil, '3')).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v3'> <soapenv:Header/> <soapenv:Body></soapenv:Body> </soapenv:Envelope>")
    end

    it "should use the string representation of the body if it is not a string" do
      expect(@iut.envelope_header_body(123, '3')).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v3'> <soapenv:Header/> <soapenv:Body>123</soapenv:Body> </soapenv:Envelope>")
    end

    it "should include the version specified in the header" do
      expect(@iut.envelope_header_body(123, '5')).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v5'> <soapenv:Header/> <soapenv:Body>123</soapenv:Body> </soapenv:Envelope>")
    end

    it "should use the string representation of version if version is not a string" do
      expect(@iut.envelope_header_body(123, 4)).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v4'> <soapenv:Header/> <soapenv:Body>123</soapenv:Body> </soapenv:Envelope>")
    end

    it "should default to version '3' if no version is specified" do
      expect(@iut.envelope_header_body(123)).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v3'> <soapenv:Header/> <soapenv:Body>123</soapenv:Body> </soapenv:Envelope>")
    end

    it "should inject the body into the header" do
      expect(@iut.envelope_header_body("abc def", '3')).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v3'> <soapenv:Header/> <soapenv:Body>abc def</soapenv:Body> </soapenv:Envelope>")
    end
  end

  context "when asked to specify content type" do
    it "should specify XML as the text content subtype, with UTF-8 as the character set encoding" do
      expect(@iut.content_type).to eq('text/xml;charset=UTF-8')
    end
  end

  context "when building a soap envelope around a message" do
    it "should treat the message as empty if it is nil" do
      expect(@iut.soap_envelope(nil)).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v2'> <soapenv:Header/> <soapenv:Body></soapenv:Body> </soapenv:Envelope>")
    end

    it "should use the string representation of the message if it is not a string" do
      expect(@iut.soap_envelope(2345)).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v2'> <soapenv:Header/> <soapenv:Body>2345</soapenv:Body> </soapenv:Envelope>")
    end

    it "should wrap the message in a soap envelope" do
      expect(@iut.soap_envelope("message present")).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v2'> <soapenv:Header/> <soapenv:Body>message present</soapenv:Body> </soapenv:Envelope>")
    end

    it "should include a urn indicator if a urn is provided" do
      expect(@iut.soap_envelope("message", "theurn")).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v2'> <soapenv:Header/> <soapenv:Body><urn:theurn generic='2.0' xmlns='urn:uddi-org:api_v2' >message</urn:theurn></soapenv:Body> </soapenv:Envelope>")
    end

    it "should raise an error InvalidTextError with 'invalid urn provided' if the urn is not a string" do
      expect {
        @iut.soap_envelope('message', 5)
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid urn provided')
    end

    it "should raise an error InvalidTextError with 'invalid urn provided' if the urn is empty" do
      expect {
        @iut.soap_envelope('message', '')
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid urn provided')
    end

    it "should raise an error InvalidTextError with 'invalid urn provided' if the urn is all spaces" do
      expect {
        @iut.soap_envelope('message', '    ')
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid urn provided')
    end

    it "should include attributes if attributes are provided" do
      expect(@iut.soap_envelope("message", "theurn", "attr1='hello' attr2='there'")).to eq("<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v2'> <soapenv:Header/> <soapenv:Body><urn:theurn generic='2.0' xmlns='urn:uddi-org:api_v2' attr1='hello' attr2='there'>message</urn:theurn></soapenv:Body> </soapenv:Envelope>")
    end

    it "should raise an error InvalidTextError with 'invalid attributes provided' if the attributes parameter is not a string" do
      expect {
        @iut.soap_envelope('message', 'theurn', 5)
      }.to raise_error(Soap4juddi::InvalidTextError, 'invalid attributes provided')
    end
  end
end