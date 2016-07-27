require 'spec_helper'
require 'helpers/test_connector'
require 'helpers/test_xml'
require 'byebug'

describe Soap4juddi::Broker do
  before :each do
    @test_connector = Soap4juddi::TestConnector.new
    @test_urns = @urns = {
      'base' => 'test_base:',
      'company' => 'test_company:',
      'domains' => 'test_domains:',
      'teams' => 'test_teams:',
      'services' => 'test_services:',
      'service-components' => 'test_service-components' }
    allow(Soap4juddi::Connector).to receive(:new).and_return(@test_connector)
    @iut = Soap4juddi::Broker.new(@test_urns)
    @iut.base_uri = 'base_uri'
    @business_key = 'test-business'
  end

  context "when initialized" do
    it "should remember URNS provided" do
      expect(@iut.urns).to eq(@test_urns)
    end

    it "should have a UDDI connector" do
      expect(@iut.soap_connector).to eq(@test_connector)
    end

    it "should have a UDDI XML parser" do
      expect(@iut.soap_xml.is_a?(Soap4juddi::XML)).to eq(true)
    end
  end

  context "when setting the base URI" do
    it "should remember the base URI" do
      expect(@iut.base_uri).to eq('base_uri')
    end
  end

  context "when saving element bindings" do
    before :each do
      @test_description = 'test description'
      @test_service = 'test-service-01'
      @test_bindings = ['http://localhost:9191/action', 'http://localhost:9292/action2']
      @no_bindings = []
      @test_urn = @urns['services']
    end

    it "should raise an InvalidElementError with message 'invalid bindings' if bindings is not an array" do
      expect {
        @iut.save_element_bindings(@test_service, "invalid", @test_urn, @test_description)
      }.to raise_error(Soap4juddi::InvalidElementError, 'invalid bindings')
    end

    it "should include the authentication token in an authorization tag" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, @test_description)
      verify_auth_body
    end

    it "should not request the binding if there are no bindings indicated" do
      @iut.save_element_bindings(@test_service, @no_bindings, @test_urn, @test_description)
      body = @test_connector.body
      expect(body.include?('bindingTemplate')).to eq(false)
    end

    it "should provide a binding template entry for each binding" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, @test_description)
      body = @test_connector.body
      expect(body.include?("<urn:bindingTemplate bindingKey='' serviceKey='#{@test_urn}#{@test_service}'><urn:description>test description</urn:description><urn:accessPoint URLType='http'>http://localhost:9191/action</urn:accessPoint><urn:tModelInstanceDetails></urn:tModelInstanceDetails></urn:bindingTemplate>")).to eq(true)
      expect(body.include?("<urn:bindingTemplate bindingKey='' serviceKey='#{@test_urn}#{@test_service}'><urn:description>test description</urn:description><urn:accessPoint URLType='http'>http://localhost:9292/action2</urn:accessPoint><urn:tModelInstanceDetails></urn:tModelInstanceDetails></urn:bindingTemplate>")).to eq(true)
    end

    it "should include the binding templates in soap bindingTemplate tags for UDDI" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, @test_description)
      body = @test_connector.body
      expect(body.include?("<urn:bindingTemplate")).to eq(true)
      expect(body.include?("</urn:bindingTemplate>")).to eq(true)
    end

    it "should translate the request into a save_binding request for UDDI" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, @test_description)
      expect(@test_connector.action).to eq('save_binding')      
    end

    it "should include accessPoint entries" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, @test_description)
      body = @test_connector.body
      expect(body.include?('<urn:accessPoint')).to eq(true)
      expect(body.include?('</urn:accessPoint>')).to eq(true)
    end

    it "should include a description if not empty" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, @test_description)
      body = @test_connector.body
      expect(body.include?("<urn:description>#{@test_description}</urn:description>")).to eq(true)
    end

    it "should include an empty description if empty" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, nil)
      body = @test_connector.body
      expect(body.include?("<urn:description></urn:description>")).to eq(true)
    end

    it "should include the service key of the element to bind to" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, nil)
      body = @test_connector.body
      expect(body.include?("test-service-01'")).to eq(true)
    end

    it "should prefix the service key with the urn provided" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, nil)
      body = @test_connector.body
      expect(body.include?("serviceKey='#{@urns['services']}test-service-01'")).to eq(true)
    end

    it "should leave the binding key empty so UDDI can generate one" do
      @iut.save_element_bindings(@test_service, @test_bindings, @test_urn, nil)
      body = @test_connector.body
      expect(body.include?("bindingKey=''")).to eq(true)
    end
  end

  context "when dealing with businesses" do
    before :each do
      @business_pattern = 'st-bu'
      @name = 'Test business'
      @descriptions = ['A test business', 'That serves customers']
      @contacts = [ {'name' => 'Darren', 'description' => 'developer', 'phone' => '1234567', 'email' => 'darren@test.com'},
                    {'name' => 'Ernst', 'description' => 'developer2', 'phone' => '7654321', 'email' => 'ernst@test.com'} ]
      @response = "<soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/'><soap:Body><ns2:businessDetail xmlns:ns2='urn:uddi-org:api_v2' generic='2.0' operator='uddi:juddi.apache.org:node1' truncated='false'><ns2:businessEntity businessKey='#{@business_key}' operator='uddi:juddi.apache.org:node1'><ns2:name>#{@name}</ns2:name><ns2:description xml:lang='en'>#{@descriptions.first}</ns2:description><ns2:description xml:lang='en'>#{@descriptions.last}</ns2:description><ns2:contacts><ns2:contact useType='(Job Title, Role)'><ns2:description>developer</ns2:description><ns2:personName>Darren</ns2:personName><ns2:phone useType='(Extension, Domestic, International, DSN)'>1234567</ns2:phone><ns2:email useType='Email'>darren@test.com</ns2:email></ns2:contact><ns2:contact useType='(Job Title, Role)'><ns2:description>developer2</ns2:description><ns2:personName>Ernst</ns2:personName><ns2:phone useType='(Extension, Domestic, International, DSN)'>7654321</ns2:phone><ns2:email useType='Email'>ernst@test.com</ns2:email></ns2:contact></ns2:contacts></ns2:businessEntity></ns2:businessDetail></soap:Body></soap:Envelope>"
      @test_connector.response = @response
    end

    context "when saving a business" do
      before :each do
        @no_contacts = []
      end

      it "should raise an InvalidElementError with message 'invalid contacts' if contacts is not an array" do
        expect {
          @iut.save_business(@business_key, @name, @descriptions, "invalid")
        }.to raise_error(Soap4juddi::InvalidElementError, 'invalid contacts')
      end

      it "should raise an InvalidElementError with message 'invalid descriptions' if descriptions is not an array" do
        expect {
          @iut.save_business(@business_key, @name, "invalid", @contacts)
        }.to raise_error(Soap4juddi::InvalidElementError, 'invalid descriptions')
      end

      it "should include the authentication token in an authorization tag" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        verify_auth_body
      end

      it "should not request the contact if there are no contacts indicated" do
        @iut.save_business(@business_key, @name, @descriptions, @no_contacts)
        body = @test_connector.body
        expect(body.include?('bindingTemplate')).to eq(false)
      end

      it "should provide a contact entry for each contact" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?("<contact useType='(Job Title, Role)'> <description>developer</description> <personName>Darren</personName> <phone useType='(Extension, Domestic, International, DSN)'>1234567</phone> <email useType='Email'>darren@test.com</email> </contact>")).to eq(true)
        expect(body.include?("<contact useType='(Job Title, Role)'> <description>developer2</description> <personName>Ernst</personName> <phone useType='(Extension, Domestic, International, DSN)'>7654321</phone> <email useType='Email'>ernst@test.com</email> </contact>")).to eq(true)
      end

      it "should include contact name" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?("<personName>"))
        expect(body.include?("</personName>"))
      end

      it "should include contact descrition" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?("<description>"))
        expect(body.include?("</description>"))
      end

      it "should include contact email" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?("<email"))
        expect(body.include?("</email>"))
      end

      it "should include contact phone" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?("<phone"))
        expect(body.include?("</phone>"))
      end

      it "should include the businessEntity in soap tags for UDDI" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?('<urn:businessEntity')).to eq(true)
        expect(body.include?('</urn:businessEntity>')).to eq(true)
      end

      it "should translate the request into a save_business request for UDDI" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        expect(@test_connector.action).to eq('save_business')      
      end

      it "should include a description if not empty" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?(@descriptions.first)).to eq(true)
        expect(body.include?(@descriptions.last)).to eq(true)
      end

      it "should not include an empty description" do
        @iut.save_business(@business_key, @name, [""], @contacts)
        body = @test_connector.body
        expect(body.include?("></urn:description>")).to eq(false)
      end

      it "should include the businessKey key of the element to bind to" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?(@business_key)).to eq(true)
      end

      it "should prefix the business key with the urn provided" do
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?("<urn:businessEntity businessKey='#{@business_key}'>")).to eq(true)
      end

      it "should set the name of the business appropriately" do 
        @iut.save_business(@business_key, @name, @descriptions, @contacts)
        body = @test_connector.body
        expect(body.include?("<urn:name>#{@name}</urn:name>")).to eq(true)      
      end
    end

    context "when retrieving details for a business" do
      it "should provide the business key" do
        @iut.get_business(@business_key)        
        body = @test_connector.body
        expect(body.include?("<urn:businessKey>#{@business_key}</urn:businessKey>")).to eq(true)      
      end

      it "should translate the request to a UDDI get_businessDetail request" do
        @iut.get_business(@business_key)
        expect(@test_connector.action).to eq('get_businessDetail')      
      end

      it "should return the business information, indexed by the business id" do
        result = @iut.get_business(@business_key)
        expect(result.first[0]).to eq(@business_key)
      end

      it "should return the business name" do
        result = @iut.get_business(@business_key)
        expect(result[@business_key]['name']).to eq(@name)
      end

      it "should return the business description" do
        result = @iut.get_business(@business_key)    
        expect(result[@business_key]['description'].include?(@descriptions.first)).to eq(true)
        expect(result[@business_key]['description'].include?(@descriptions.last)).to eq(true)
      end

      it "should return all contacts for the business" do
        result = @iut.get_business(@business_key)
        cons = result[@business_key]['contacts']
        expect(cons.size).to eq(2)
        expect(verify_contact(cons, @contacts.first)).to eq(true)
        expect(verify_contact(cons, @contacts.last)).to eq(true)
      end
    end
  end

  context "when finding a business" do
    before :each do
      @business_pattern = 'st-bu'
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:businessList xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:businessInfos><ns2:businessInfo businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">An Apache jUDDI Node</ns2:name><ns2:description xml:lang="en">This is a UDDI registry node as implemented by Apache jUDDI.</ns2:description><ns2:serviceInfos><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-publisher" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">jUDDI Publisher Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-custodytransfer" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Custody and Ownership Transfer Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-inquiry-rest" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Inquiry REST Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-inquiry" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Inquiry Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-publish" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Publish Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:replication" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Replication API Version 3</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-security" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Security Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-subscriptionlistener" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Subscription Listener Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-subscription" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Subscription Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-valueset" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Value Set API Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-valueset-cache" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Value Set Caching API Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-inquiryv2" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDIv2 Inquiry Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-publishv2" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDIv2 Publish Service</ns2:name></ns2:serviceInfo></ns2:serviceInfos></ns2:businessInfo><ns2:businessInfo businessKey="test_teams:billing and admin"><ns2:name>billing and admin</ns2:name><ns2:description xml:lang="en">some description</ns2:description><ns2:description xml:lang="en">another descrition</ns2:description><ns2:serviceInfos/></ns2:businessInfo><ns2:businessInfo businessKey="test_domains:domain_perspective_1"><ns2:name>domain_perspective_1</ns2:name><ns2:serviceInfos/></ns2:businessInfo><ns2:businessInfo businessKey="test_company:"><ns2:name>TestCompany Pty Ltd</ns2:name><ns2:serviceInfos><ns2:serviceInfo serviceKey="test_service-components:some-service-1.somewhere.net" businessKey="test_company:"><ns2:name>some-service-1.somewhere.net</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="test_service-components:some-service-2.somewhere.net" businessKey="test_company:"><ns2:name>some-service-2.somewhere.net</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="test_service-components:sc1.dev.auto-h.net" businessKey="test_company:"><ns2:name>sc1.dev.auto-h.net</ns2:name></ns2:serviceInfo></ns2:serviceInfos></ns2:businessInfo><ns2:businessInfo businessKey="test_domains:profile transfers"><ns2:name>profile transfers</ns2:name><ns2:description xml:lang="en">hey description</ns2:description><ns2:description xml:lang="en">ho description</ns2:description><ns2:serviceInfos/></ns2:businessInfo></ns2:businessInfos></ns2:businessList></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    it "should translate into an approximate match qualifier" do
      @iut.find_business(@business_pattern)
      body = @test_connector.body
      expect(body.include?("<urn:findQualifiers><urn:findQualifier>approximateMatch</urn:findQualifier></urn:findQualifiers>")).to eq(true)
    end

    it "should translate the request to a UDDI find_business request" do
      @iut.find_business(@business_pattern)
      expect(@test_connector.action).to eq('find_business')      
    end

    it "should return the result as a business dictionary" do
      result = @iut.find_business(@business_pattern)  
      expect(result['businesses']['billing and admin']['id']).to eq('test_teams:billing and admin')
      expect(result['businesses']['billing and admin']['name']).to eq('billing and admin')
      expect(result['businesses']['profile transfers']['id']).to eq('test_domains:profile transfers')
      expect(result['businesses']['profile transfers']['name']).to eq('profile transfers')
    end
  end

  context "when deleting a business" do
    before :each do
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:dispositionReport xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:result errno="123"/></ns2:dispositionReport></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    it "should translate the request to a UDDI delete_business request" do
      @iut.delete_business(@business_key)
      expect(@test_connector.action).to eq('delete_business')      
    end

    it "should insert the business key into the request for deletion" do
      @iut.delete_business(@business_key)
      body = @test_connector.body
      expect(body.include?("<urn:businessKey>#{@business_key}</urn:businessKey>")).to eq(true)
    end

    it "should report any errors" do
      expect(@iut.delete_business(@business_key)).to eq({"errno"=>"123"})
    end
  end

  context "when finding services" do
    before :each do
      @service_pattern = 'search'
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:serviceList xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:serviceInfos><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-publisher" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">jUDDI Publisher Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="test_service-components:some-service-1.somewhere.net" businessKey="test_company:"><ns2:name>some-service-1.somewhere.net</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="test_service-components:some-service-2.somewhere.net" businessKey="test_company:"><ns2:name>some-service-2.somewhere.net</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="test_service-components:sc1.dev.auto-h.net" businessKey="test_company:"><ns2:name>sc1.dev.auto-h.net</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="test_services:search me" businessKey="test_company:"><ns2:name>search me</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="test_services:search me also" businessKey="test_company:"><ns2:name>search me also</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-custodytransfer" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Custody and Ownership Transfer Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-inquiry-rest" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Inquiry REST Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-inquiry" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Inquiry Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-publish" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Publish Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:replication" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Replication API Version 3</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-security" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Security Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-subscriptionlistener" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Subscription Listener Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-subscription" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Subscription Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-valueset" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Value Set API Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-valueset-cache" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDI Value Set Caching API Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-inquiryv2" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDIv2 Inquiry Service</ns2:name></ns2:serviceInfo><ns2:serviceInfo serviceKey="uddi:juddi.apache.org:services-publishv2" businessKey="uddi:juddi.apache.org:node1"><ns2:name xml:lang="en">UDDIv2 Publish Service</ns2:name></ns2:serviceInfo></ns2:serviceInfos></ns2:serviceList></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    it "should translate into an approximate match qualifier" do
      @iut.find_services(@service_pattern)
      body = @test_connector.body
      expect(body.include?("<urn:findQualifier>approximateMatch</urn:findQualifier>")).to eq(true)
    end

    it "should translate into an orAllKeys qualifier" do
      @iut.find_services(@service_pattern)
      body = @test_connector.body
      expect(body.include?("<urn:findQualifier>orAllKeys</urn:findQualifier>")).to eq(true) 
    end

    it "should translate the request to a UDDI find_service request" do
      @iut.find_services(@service_pattern)
      expect(@test_connector.action).to eq('find_service')      
    end

    it "should return the result as a service dictionary" do
      result = @iut.find_services(@service_pattern)
      expect(result['services']['search me']['id']).to eq('test_services:search me')
      expect(result['services']['search me']['name']).to eq('search me')
      expect(result['services']['search me also']['id']).to eq('test_services:search me also')
      expect(result['services']['search me also']['name']).to eq('search me also')
    end
  end

  context "when finding service components" do
    it "should leverage find_services and indicate service components' urn" do
      expect(@iut).to receive(:find_services).with('pattern', 'service-components')
      @iut.find_service_components('pattern')
    end
  end

  context "when finding binding element" do
    before :each do
      @name = 'name'
      @urn = 'urn'
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:serviceDetail xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:businessService serviceKey="test_company:test_services:search me" businessKey="business-key"><ns2:name>search me</ns2:name><ns2:description xml:lang="en">pretty please</ns2:description><ns2:bindingTemplates><ns2:bindingTemplate serviceKey="test_services:search me" bindingKey="uddi:juddi.apache.org:2db2cb14-24c5-491a-a746-e8aabaab8845"><ns2:description>service uri</ns2:description><ns2:accessPoint URLType="http">http://one-uri.com/my_service</ns2:accessPoint><ns2:tModelInstanceDetails/></ns2:bindingTemplate><ns2:bindingTemplate serviceKey="test_services:search me" bindingKey="uddi:juddi.apache.org:57378d58-024c-4348-9670-bccb15e7a2c9"><ns2:description>service uri</ns2:description><ns2:accessPoint URLType="http">http://two-uri.com/my_service</ns2:accessPoint><ns2:tModelInstanceDetails/></ns2:bindingTemplate></ns2:bindingTemplates><ns2:categoryBag><ns2:keyedReference tModelKey="uddi:uddi.org:wadl:types" keyName="service-definition" keyValue="http://de.finiti.on"/></ns2:categoryBag></ns2:businessService></ns2:serviceDetail></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    it "should translate into a UDDI get_serviceDetail request" do
      @iut.find_element_bindings(@name, @urn)
      expect(@test_connector.action).to eq('get_serviceDetail')      
    end

    it "should get detail for the serviceKey as a combination of urn and name" do
      @iut.find_element_bindings(@name, @urn)
      body = @test_connector.body
      expect(body.include?("<urn:serviceKey>#{@urn}#{@name}</urn:serviceKey>")).to eq(true) 
    end

    it "should return the result as a binding dictionary" do
      result = @iut.find_element_bindings(@name, @urn)
      test_one = 'http://one-uri.com/my_service'
      test_two = 'http://two-uri.com/my_service'
      result['bindings'].each do |_id, binding|
        uri = binding['access_point']
        matched = ((uri == test_one) or (uri == test_two))
        expect(matched).to eq(true)
      end
    end
  end

  context "when deleting bindings" do
    before :each do
      @binding_key = 'uri'
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:dispositionReport xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:result errno="123"/></ns2:dispositionReport></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    it "should translate the request to a UDDI delete_binding request" do
      @iut.delete_binding(@binding_key)
      expect(@test_connector.action).to eq('delete_binding')      
    end

    it "should insert the binding key into the request for deletion" do
      @iut.delete_binding(@binding_key)
      body = @test_connector.body
      expect(body.include?("<urn:bindingKey>#{@binding_key}</urn:bindingKey>")).to eq(true)
    end

    it "should report any errors" do
      expect(@iut.delete_binding(@binding_key)).to eq({"errno"=>"123"})
    end
  end

  context "when retrieving a service element" do
    before :each do
      @service_name = 'search me'
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:serviceDetail xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:businessService serviceKey="test_services:search me" businessKey="test_company"><ns2:name>search me</ns2:name><ns2:description xml:lang="en">pretty please</ns2:description><ns2:bindingTemplates><ns2:bindingTemplate serviceKey="test_services:search me" bindingKey="uddi:juddi.apache.org:57378d58-024c-4348-9670-bccb15e7a2c9"><ns2:description>service uri</ns2:description><ns2:accessPoint URLType="http">http://two-uri.com/my_service</ns2:accessPoint><ns2:tModelInstanceDetails/></ns2:bindingTemplate></ns2:bindingTemplates><ns2:categoryBag><ns2:keyedReference tModelKey="uddi:uddi.org:wadl:types" keyName="service-definition" keyValue="http://de.finiti.on"/></ns2:categoryBag></ns2:businessService></ns2:serviceDetail></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    it "should provide the service element key, prefixed by the urn" do
      @iut.get_service_element(@service_name, @urns["services"])        
      body = @test_connector.body
      expect(body.include?("<urn:serviceKey>#{@urns['services']}#{@service_name}</urn:serviceKey>")).to eq(true)      
    end

    it "should translate the request to a UDDI get_serviceDetail request" do
      @iut.get_service_element(@service_name, @urns["services"])        
      expect(@test_connector.action).to eq('get_serviceDetail')      
    end

    it "should return the service information" do
      result = @iut.get_service_element(@service_name, @urns["services"])
      expect(result).to eq({"name"=>"search me", "key" => "#{@urns['services']}#{@service_name}", "description"=>["pretty please"], "definition"=>"http://de.finiti.on"})
    end
  end
  
  context "when dealing with saving and updating services" do
    before :each do
      @name = 'search me'
      @description = ['pretty please']
      @definition = 'http://de.finiti.on/wadl'
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:serviceDetail xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:businessService serviceKey="test_services:search me" businessKey="test_company"><ns2:name>search me</ns2:name><ns2:description xml:lang="en">pretty please</ns2:description><ns2:categoryBag><ns2:keyedReference tModelKey="uddi:uddi.org:wadl:types" keyName="service-definition" keyValue="http://de.finiti.on/wadl"/></ns2:categoryBag></ns2:businessService></ns2:serviceDetail></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    context "when saving a service" do
      before :each do
        allow(@iut).to receive(:find_element_bindings_access_points).and_return({'data' => { 'result' => [] }})
        allow(@iut).to receive(:save_element_bindings)
      end

      it "should translate the request to a UDDI save_service request" do
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
        expect(@test_connector.action).to eq('save_service')
      end
      
      it "should compile the service key using the urn and service name" do
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
        body = @test_connector.body
        expect(body.include?("serviceKey='#{@urns['services']}#{@name}'")).to eq(true)      
      end

      it "should set the service definition to the definition provided, as a keyed reference" do
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
        body = @test_connector.body
        expect(body.include?("<urn:keyedReference tModelKey='uddi:uddi.org:wadl:types' keyName='service-definition' keyValue='#{@definition}'></urn:keyedReference>")).to eq(true)      
      end

      it "should set the service name to the name provided" do
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
        body = @test_connector.body
        expect(body.include?("<urn:name>#{@name}</urn:name>")).to eq(true)      
      end

      it "should set the service description to the description provided" do
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
        body = @test_connector.body
        expect(body.include?("<urn:description xml:lang='en'>#{@description[0]}</urn:description>")).to eq(true)      
      end

      it "should set the service business key to the business key provided" do
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
        body = @test_connector.body
        expect(body.include?("businessKey='#{@business_key}'")).to eq(true)      
      end

      it "should return service name on successful save / update" do
        result = @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
        expect(result).to eq({"test_services:search me"=>"search me"})
      end
    end

    context "when saving a service element, and preserving bindings" do
      it "should preserve bindings when saving, since UDDI save will delete these" do
        @binding1 = 'http://some-binding.com'
        @binding2 = 'http://some-binding2.com'
        expect(@iut).to receive(:find_element_bindings_access_points).with(@name, @urns['services']).and_return({'data' => { 'result' => [@binding1, @binding2] }})
        expect(@iut).to receive(:save_element_bindings).with(@name, [@binding1, @binding2], @urns['services'], '')
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
      end

      it "should correctly handle saving when there are no existing bindings for the service" do
        expect(@iut).to receive(:find_element_bindings_access_points).with(@name, @urns['services']).and_return({'data' => { 'result' => [] }})
        expect(@iut).to receive(:save_element_bindings).with(@name, [], @urns['services'], '')
        @iut.save_service_element(@name, @description, @definition, @urns['services'], @business_key)
      end
    end
  end

  context "when deleting service elements" do
    before :each do
      @name = 'search me'
      @response = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><ns2:dispositionReport xmlns:ns2="urn:uddi-org:api_v2" generic="2.0" operator="uddi:juddi.apache.org:node1" truncated="false"><ns2:result errno="123"/></ns2:dispositionReport></soap:Body></soap:Envelope>'
      @test_connector.response = @response
    end

    it "should translate the request to a UDDI delete_service request" do
      @iut.delete_service_element(@name, @urns['services'])
      expect(@test_connector.action).to eq('delete_service')      
    end

    it "should insert the name into the request for deletion" do
      @iut.delete_service_element(@name, @urns['services'])
      body = @test_connector.body
      expect(body.include?("<urn:serviceKey>#{@urns['services']}#{@name}</urn:serviceKey>")).to eq(true)
    end

    it "should report any errors" do
      expect(@iut.delete_service_element(@name, @urns['services'])).to eq({"errno"=>"123"})
    end
  end

  context "when authenticating" do
    it "should delegate to the soap connector" do
      expect(@test_connector).to receive(:authenticate).with('user', 'password')
      @iut.authenticate('user', 'password')
    end
  end

  context "when authorizing" do
    it "should delegate to the soap connector" do
      expect(@test_connector).to receive(:authorize).with(@iut.base_uri)
      @iut.authorize
    end
  end

  def verify_auth_body
    body = @test_connector.body
    expect(body.include?('<urn:authInfo>')).to eq(true)
    expect(body.include?('authtoken:')).to eq(true)
    expect(body.include?('</urn:authInfo>')).to eq(true)
  end 

  def verify_contact(contacts, contact)
    contacts.each do |compare|
      return true if
        (compare['name'] == contact['name']) and
        (compare['description'] == contact['description']) and
        (compare['phone'] == contact['phone']) and
        (compare['email'] == contact['email'])
    end
    false
  end   
end