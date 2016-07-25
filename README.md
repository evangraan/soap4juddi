# Soap4juddi

Soap4juddi provides connector, xml and brokerage facilities to interested consumers. It takes care of talking http or https SOAP to a jUDDI instance, as well as a means of translating the consumer's business domain into the jUDDI business domain (businesses, entities, bindings, etc.)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'soap4juddi'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install soap4juddi

## Usage

Note: all the URNs indicated below *must* be present in the urns dictionary.

    @urns = { 'base' => ServiceRegistry::BASE_URN,
              'company' => ServiceRegistry::REGISTRY_URN,
              'domains' => ServiceRegistry::DOMAINS_URN,
              'teams' => ServiceRegistry::TEAMS_URN,
              'services' => ServiceRegistry::SERVICES_URN,
              'service-components' => ServiceRegistry::SERVICE_COMPONENTS_URN}
    broker = ::Soap4juddi::Broker.new(@urns)
    broker.base_uri('https://uddi.server.com:1234')
    broker.authenticate('user', 'credential')
    broker.save_service_element('service-name', 'service-description', 'service-definition-uri', @urns['services'], 'generated-business-key')
    etc...

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and feature requests are welcome by email to ernst dot van dot graan at hetzner dot co dot za. This gem is sponsored by Hetzner (Pty) Ltd (http://hetzner.co.za)

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

