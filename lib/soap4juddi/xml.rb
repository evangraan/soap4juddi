module Soap4juddi  
  class XML
    def element_with_key_value(element, key, value, attributes = nil)
      element_with_value(element, "#{key}:#{value}", attributes)
    end

    def element_with_value(element, value, attributes = nil)
      validate_element(element)
      xml = "<urn:#{element}"
      xml = append_key_value_attributes_to_xml(xml, attributes) if attributes
      xml + ">#{value}</urn:#{element}>"
    end   
      
    def extract_value(soap, key)
      validate_text(soap, 'text') and validate_text(key, 'key')
      extract_value_in_quotes_using_key(soap, key)
    end

    def envelope_header_body(text, version = 3)
      "<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:urn='urn:uddi-org:api_v#{version.to_s}'> <soapenv:Header/> <soapenv:Body>#{text.to_s}</soapenv:Body> </soapenv:Envelope>"
    end

    def soap_envelope(message, urn = nil, attributes = nil)
      validate_text(urn, 'urn') if urn
      validate_text(attributes, 'attributes') if attributes
      text = inject_urn_and_attributes_into_message(message, urn, attributes)
      envelope_header_body(text, 2)
    end
 
    def content_type
      'text/xml;charset=UTF-8'
    end

    private

    def validate_element(element)
      raise Soap4juddi::InvalidElementError.new('invalid element provided') if element.nil?
      raise Soap4juddi::InvalidElementError.new('invalid element provided') unless element.is_a?(String)
      raise Soap4juddi::InvalidElementError.new('no element provided') if element.strip == ''
    end

    def append_key_value_attributes_to_xml(xml, attributes)
      attributes.each do |a, v|
        xml += " #{a}='#{v}'"
      end
      xml
    end    

    def validate_text(text, label)
      raise Soap4juddi::InvalidTextError.new("no #{label} provided") if text.nil?
      raise Soap4juddi::InvalidTextError.new("invalid #{label} provided") if invalid_text?(text)
      true
    end

    def invalid_text?(text)
      ((not text.is_a?(String)) or (text.strip == ''))
    end   

    def extract_value_in_quotes_using_key(soap, key)
      extract_value_in_arbitrary_quotes_following_key_and_equal_sign(
        collapse_spaces_around_equal_sign(soap), key
      )
    rescue
      nil
    end

    def collapse_spaces_around_equal_sign(soap)
      data = soap
      data[/\s*=\s*/] = '='
      data
    end

    def extract_value_in_arbitrary_quotes_following_key_and_equal_sign(soap, key)
      result = soap[/#{key}="(.*?)"/, 1]
      result ||= soap[/#{key}='(.*?)'/, 1]
      result
    end

    def inject_urn_and_attributes_into_message(message, urn, attributes)
      text = ""
      text += "<urn:#{urn} generic='2.0' xmlns='urn:uddi-org:api_v2' " + (attributes.nil? ? "" : attributes) + ">" if urn
      text += message.to_s
      text += "</urn:#{urn}>" if urn
      text
    end
  end
end
