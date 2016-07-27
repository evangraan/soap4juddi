require 'soap4juddi/xml'
require 'soap4juddi/connector'

module Soap4juddi
  class Broker
    attr_reader :urns
    attr_reader :soap_connector
    attr_reader :soap_xml
    attr_accessor :base_uri

    def initialize(urns)
      @urns = urns
      @soap_connector = Soap4juddi::Connector.new
      @soap_xml = Soap4juddi::XML.new
    end

    def save_element_bindings(service, bindings, urn, description)
      validate_elements(bindings, 'bindings')
      body = add_bindings("", service, bindings, urn, description)
      @soap_connector.request_soap(@base_uri, 'publishv2', 'save_binding', add_auth_body(body)) do | res|
        res.body
      end
    end

    def save_business(key, name, descriptions, contacts)
      validate_elements(contacts, 'contacts')
      validate_elements(descriptions, 'descriptions')
      body = build_business_entity(key, name, descriptions, contacts)
      @soap_connector.request_soap(@base_uri,
                   'publishv2', 'save_business',
                   add_auth_body(body)) do | res|
        extract_business(res.body)
      end
    end

    def get_business(key)
      @soap_connector.request_soap(@base_uri, 'inquiryv2', 'get_businessDetail', @soap_xml.element_with_value('businessKey', key)) do |res|
        extract_business(res.body)
      end
    end

    def find_business(pattern)
      qualifiers = @soap_xml.element_with_value('findQualifiers', @soap_xml.element_with_value('findQualifier', 'approximateMatch'))
      xml = @soap_xml.element_with_value('name', pattern)
      @soap_connector.request_soap(@base_uri, 'inquiryv2', 'find_business', "#{qualifiers} #{xml}") do |res|
        extract_business_entries(res.body)
      end
    end 

    def delete_business(key)
      xml = @soap_xml.element_with_value('businessKey', key)
      @soap_connector.request_soap(@base_uri, 'publishv2', 'delete_business', add_auth_body(xml)) do |res|
        { 'errno' => extract_errno(res.body) }
      end
    end

    def find_services(pattern, type = 'services')
      qualifier1 = @soap_xml.element_with_value('findQualifier', 'approximateMatch')
      qualifier2 = @soap_xml.element_with_value('findQualifier', 'orAllKeys')
      qualifiers = @soap_xml.element_with_value('findQualifiers', "#{qualifier1}#{qualifier2}")
      xml = @soap_xml.element_with_value('name', pattern)
      @soap_connector.request_soap(@base_uri, 'inquiryv2', 'find_service', "#{qualifiers} #{xml}") do |res|
        extract_service_entries_elements(res.body, @urns[type])
      end
    end

    def find_service_components(pattern)
      find_services(pattern, 'service-components')
    end

    def find_element_bindings(name, urn)
      @soap_connector.request_soap(@base_uri, 'inquiryv2', 'get_serviceDetail', @soap_xml.element_with_value('serviceKey', "#{urn}#{name}")) do |res|
        extract_bindings(res.body)
      end
    end

    def delete_binding(binding)
      xml = @soap_xml.element_with_value('bindingKey', binding)
      @soap_connector.request_soap(@base_uri, 'publishv2', 'delete_binding', add_auth_body(xml)) do |res|
        { 'errno' => extract_errno(res.body) }
      end
    end

    def get_service_element(name, urn)
      key = name.include?(urn) ? name : "#{urn}#{name}"
      xml = @soap_xml.element_with_value('serviceKey', key)
      @soap_connector.request_soap(@base_uri, 'inquiryv2', 'get_serviceDetail', "#{xml}") do |res|
        { 'name' => extract_name(res.body),
          'key' => key,
          'description' => extract_descriptions(res.body),
          'definition' => extract_service_definition(res.body) }
      end
    end

    def save_service_element(name, description, definition, urn, business_key)
      bindings = find_element_bindings_access_points(name, urn)['data']['result']
      result = save_service_element_with_side_effect_which_clears_bindings(name, description, definition, urn, business_key)
      save_element_bindings(name, bindings, urn, '')
      result
    end

    def delete_service_element(name, urn)
      service_key = @soap_xml.element_with_value('serviceKey', "#{urn}#{name}")
      @soap_connector.request_soap(@base_uri, 'publishv2', 'delete_service', add_auth_body(service_key)) do |res|
        { 'errno' => extract_errno(res.body) }
      end
    end

    def authenticate(auth_user, auth_password)
      @soap_connector.authenticate(auth_user, auth_password)
    end

    def authorize
      @auth_token = @soap_connector.authorize(@base_uri)
    end

    private

    def extract_service_entry_and_adjust(entries, entry, urn)
      service = entry[/<ns2:serviceInfo (.*?)<\/ns2:serviceInfo>/, 1]
      return entries, entry, true if service.nil? or ((service.is_a? String) and (service.strip == ""))
      id = @soap_xml.extract_value(service, 'serviceKey')
      entries[id.gsub(urn, "")] = { 'id' => id, 'name' => extract_name(service) } if id.include?(urn)
      entry[/<ns2:serviceInfo (.*?)<\/ns2:serviceInfo>/, 1] = ""
      entry.gsub!("<ns2:serviceInfo </ns2:serviceInfo>", "")
      entry = nil if entry.strip == ""
      return entries, entry, false
    end

    def extract_business_entry_and_adjust(entries, entry)
      business = entry[/<ns2:businessInfo (.*?)<\/ns2:businessInfo>/, 1]
      return entries, entry, true if business.nil? or ((business.is_a? String) and (business.strip == ""))
      business[/<ns2:serviceInfos(.*?)<\/ns2:serviceInfos>/, 1] = "" if business[/<ns2:serviceInfos(.*?)<\/ns2:serviceInfos>/, 1]
      id = @soap_xml.extract_value(entry, 'businessKey')
      key = id.gsub(@urns['domains'], "").gsub(@urns['teams'], "")
      entries[key] = { 'id' => id, 'name' => extract_name(business) }
      entry[/<ns2:businessInfo (.*?)<\/ns2:businessInfo>/, 1] = ""
      entry.gsub!("<ns2:businessInfo </ns2:businessInfo>", "")
      entry = nil if entry.strip == ""
      return entries, entry, false
    end

    def extract_contact_entry_and_adapt(entries, entry)
      contact, entry = reduce_entry_and_extract_contact(entry)
      return entries, entry, true if invalid_contact?(contact)
      entries << { 'name' => extract_person_name(contact), 'description' => extract_description(contact), 'phone' => extract_phone(contact), 'email' => extract_email(contact)}
      entry = reduce_entry_for_next_extraction(entry)
      return entries, entry, false
    end

    def reduce_entry_for_next_extraction(entry)
      entry[/<ns2:contact (.*?)<\/ns2:contact>/, 1] = ""
      entry.gsub!("<ns2:contact </ns2:contact>", "")
      entry = nil if entry.strip == ""
      entry
    end

    def reduce_contact_fields(entry)
      entry.gsub!('useType="(Extension, Domestic, International, DSN)"', "")
      entry.gsub!('useType="Email"', "")
      entry.gsub!("useType='(Extension, Domestic, International, DSN)'", "")
      entry.gsub!("useType='Email'", "")
      entry
    end

    def invalid_contact?(contact)
      contact.nil? or ((contact.is_a? String) and (contact.strip == ""))
    end

    def reduce_entry_and_extract_contact(entry)
      if entry
        entry = reduce_contact_fields(entry)
        contact = entry[/<ns2:contact (.*?)<\/ns2:contact>/, 1]
      end
      return contact, entry
    end

    def extract_service(soap)
      entries = {}
      entries[@soap_xml.extract_value(soap, 'serviceKey')] = extract_name(soap)
      entries
    end

    def save_service_element_with_side_effect_which_clears_bindings(name, description, definition, urn, business_key)
      xml = build_service_xml(name, description, definition, urn, business_key)
      result = @soap_connector.request_soap(@base_uri, 'publishv2', 'save_service', add_auth_body(xml)) do | res|
        extract_service(res.body)
      end
      result
    end

    def build_service_xml(name, description, definition, urn, business_key)
      service_details = @soap_xml.element_with_value('name', name)
      service_details = add_descriptions(service_details, description)
      service_details = add_definition(service_details, definition)
      @soap_xml.element_with_value('businessService', service_details, {'businessKey' => business_key, 'serviceKey' => "#{urn}#{name}"})
    end

    def add_auth_body(body)
      body =  auth_body + body
    end

    def extract_service_entries_elements(soap, urn)
      entries = {}
      entry = soap[/<ns2:serviceInfos>(.*?)<\/ns2:serviceInfos>/, 1]
      while entry do
        entries, entry, should_break = extract_service_entry_and_adjust(entries, entry, urn)
        break if should_break
      end
      { 'services' => entries }
    end

    def extract_business_entries(soap)
      entries = {}
      entry = soap[/<ns2:businessList (.*?)<\/ns2:businessList>/, 1]
      while entry do
        entries, entry, should_break = extract_business_entry_and_adjust(entries, entry)
        break if should_break
      end
      { 'businesses' => entries }
    end

    def add_definition(body, definition)
      if definition and not (definition.strip == "")
        keyedReference = @soap_xml.element_with_value('keyedReference', '', {'tModelKey' => 'uddi:uddi.org:wadl:types', 'keyName' => 'service-definition', 'keyValue' => definition})
        return body + @soap_xml.element_with_value('categoryBag', keyedReference)
      end
      body
    end
   
    def add_descriptions(body, descriptions)
      if (descriptions) and (not descriptions.empty?)
        descriptions.each do |desc|
          body = add_description(body, desc)
        end
      end
      body
    end

    def add_description(body, desc)
      xml = @soap_xml.element_with_value('description', desc, {'xml:lang' => 'en'})
      body = "#{body}#{xml}" if desc and not (desc == "")
      body
    end

    def add_bindings(body, service, bindings, urn, description)
      if (bindings) and (not bindings.empty?)
        bindings.each do |binding|
          body = add_binding(body, service, binding, urn, description)
        end
      end
      body
    end

    def add_contacts(body, contacts)
      if (contacts) and (not contacts.empty?)
        # byebug
        contacts_xml = add_contacts_to_xml("", contacts)
        xml = @soap_xml.element_with_value("contacts", contacts_xml)
        body = "#{body}#{xml}" if xml and not (xml == "")
      end
      body
    end

    def add_contacts_to_xml(contacts_xml, contacts)
      contacts.each do |contact|
        contact_details = "<contact useType='(Job Title, Role)'> <description>#{contact['description']}</description> <personName>#{contact['name']}</personName> <phone useType='(Extension, Domestic, International, DSN)'>#{contact['phone']}</phone> <email useType='Email'>#{contact['email']}</email> </contact>"
        contacts_xml = contacts_xml + contact_details
      end 
      contacts_xml
    end

    def build_business_entity(key, name, descriptions, contacts)
      body = @soap_xml.element_with_value("name", name)
      body = add_descriptions(body, descriptions)
      body = add_contacts(body, contacts)
      @soap_xml.element_with_value('businessEntity', body, {'businessKey' => key})
    end
 
    def add_binding(body, service, binding, urn, description)
      access_point = @soap_xml.element_with_value('accessPoint', binding, {'URLType' => extract_binding_url_type(binding)})
      description_data = @soap_xml.element_with_value('description', description)
      model_instance_details = @soap_xml.element_with_value('tModelInstanceDetails', '')
      binding_template = @soap_xml.element_with_value(
        "bindingTemplate",
        "#{description_data}#{access_point}#{model_instance_details}",
        {'bindingKey' => '', 'serviceKey' => "#{urn}#{service}"})
      body + binding_template
    end

    def validate_elements(elements, label)
      raise Soap4juddi::InvalidElementError.new("invalid #{label}") if (elements) and (not elements.is_a?(Array))
      true
    end

    def extract_business(soap)
      entries = {}
      index = @soap_xml.extract_value(soap, 'businessKey').gsub(@urns['domains'], "").gsub(@urns['teams'], "")
      name = extract_name(soap)
      contacts = extract_contacts(soap)
      descriptions = extract_descriptions(soap)
      entries[index] = { 'name' => name, 'description' => descriptions, 'contacts' => contacts }
      entries
    end

    def extract_errno(soap)
      soap[/<ns2:result errno="(.*?)"\/>/, 1]
    end

    def auth_body
      @soap_xml.element_with_key_value("authInfo", "authtoken", @auth_token)
    end

    def find_element_bindings_access_points(name, urn)
      @soap_connector.request_soap(@base_uri, 'inquiryv2', 'get_serviceDetail', @soap_xml.element_with_value('serviceKey', "#{urn}#{name}")) do |res|
        extract_bindings_access_points(res.body)
      end
    end

    def extract_service_definition(soap)
      soap[/<ns2:keyedReference tModelKey="uddi:uddi.org:wadl:types" keyName="service-definition" keyValue="(.*?)"\/>/, 1]
    end

    def extract_bindings(soap)
      entries = {}
      entry = soap[/<ns2:bindingTemplates>(.*?)<\/ns2:bindingTemplates>/, 1]
      while entry do
        binding = entry[/<ns2:bindingTemplate (.*?)<\/ns2:bindingTemplate>/, 1]
        break if binding.nil? or ((binding.is_a? String) and (binding.strip == ""))
        id = @soap_xml.extract_value(binding, 'bindingKey')
        entries[id] = {'access_point' => extract_access_point(binding), 'description' => extract_description(binding)}
        entry[/<ns2:bindingTemplate (.*?)<\/ns2:bindingTemplate>/, 1] = ""
        entry.gsub!("<ns2:bindingTemplate </ns2:bindingTemplate>", "")
        entry = nil if entry.strip == ""
      end
      { 'bindings' => entries }
    end

    def extract_contacts(soap)
      entries = []
      entry = soap[/<ns2:contacts>(.*?)<\/ns2:contacts>/, 1]
      while entry do
        entries, entry, should_break = extract_contact_entry_and_adapt(entries, entry)
        break if should_break
      end
      entries
    end

    def extract_bindings_access_points(soap)
      entries = []
      entry = soap[/<ns2:bindingTemplates>(.*?)<\/ns2:bindingTemplates>/, 1]
      while entry do
        binding = entry[/<ns2:bindingTemplate (.*?)<\/ns2:bindingTemplate>/, 1]
        break if binding.nil? or ((binding.is_a? String) and (binding.strip == ""))
        id = @soap_xml.extract_value(binding, 'bindingKey')
        entries << extract_access_point(binding)
        entry[/<ns2:bindingTemplate (.*?)<\/ns2:bindingTemplate>/, 1] = ""
        entry.gsub!("<ns2:bindingTemplate </ns2:bindingTemplate>", "")
        entry = nil if entry.strip == ""
      end
      entries
    end

    def extract_access_point(soap)
      soap[/^.*>(.*?)<\/ns2:accessPoint>/, 1]
    end

    def extract_name(soap)
      name = soap[/<ns2:name xml:lang="en">(.*?)<\/ns2:name>/, 1]
      name ||= soap[/<ns2:name xml:lang='en'>(.*?)<\/ns2:name>/, 1]
      name ||= soap[/<ns2:name>(.*?)<\/ns2:name>/, 1]
      name
    end

    def extract_description(soap)
      description = soap[/<ns2:description xml:lang="en">(.*?)<\/ns2:description>/, 1]
      description ||= soap[/<ns2:description xml:lang='en'>(.*?)<\/ns2:description>/, 1]
      description ||= soap[/<ns2:description>(.*?)<\/ns2:description>/, 1]
      description
    end

    def extract_email(soap)
      email = soap[/<ns2:email xml:lang="en">(.*?)<\/ns2:email>/, 1]
      email ||= soap[/<ns2:email xml:lang='en'>(.*?)<\/ns2:email>/, 1]
      email ||= soap[/<ns2:email >(.*?)<\/ns2:email>/, 1]
      email
    end

    def extract_person_name(soap)
      person_name = soap[/<ns2:personName xml:lang="en">(.*?)<\/ns2:personName>/, 1]
      person_name ||= soap[/<ns2:personName xml:lang='en'>(.*?)<\/ns2:personName>/, 1]
      person_name ||= soap[/<ns2:personName>(.*?)<\/ns2:personName>/, 1]
      person_name
    end

    def extract_phone(soap)
      phone = soap[/<ns2:phone xml:lang="en">(.*?)<\/ns2:phone>/, 1]
      phone ||= soap[/<ns2:phone xml:lang='en'>(.*?)<\/ns2:phone>/, 1]
      phone ||= soap[/<ns2:phone >(.*?)<\/ns2:phone>/, 1]
      phone
    end

    def extract_descriptions(soap)
      descriptions = []
      description = soap[/<ns2:description xml:lang="en">(.*?)<\/ns2:description>/, 1]
      description ||= soap[/<ns2:description xml:lang='en'>(.*?)<\/ns2:description>/, 1]
      while description do
        descriptions << description
        soap.gsub!("<ns2:description xml:lang=\"en\">#{description}<\/ns2:description>", "")
        soap.gsub!("<ns2:description xml:lang='en'>#{description}<\/ns2:description>", "")
        description = soap[/<ns2:description xml:lang="en">(.*?)<\/ns2:description>/, 1]
        description ||= soap[/<ns2:description xml:lang='en'>(.*?)<\/ns2:description>/, 1]
      end
      descriptions
    end

    def extract_binding_url_type(binding)
      url_type = nil
      url_type = 'https' if binding.include?('https')
      url_type = 'http' if (not binding.include?('https') and binding.include?('http'))
      url_type ||= 'unknown'
      url_type
    end
  end
end
