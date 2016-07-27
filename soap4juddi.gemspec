# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'soap4juddi/version'

Gem::Specification.new do |spec|
  spec.name          = "soap4juddi"
  spec.version       = Soap4juddi::VERSION
  spec.authors       = ["Ernst van Graan"]
  spec.email         = ["ernst.van.graan@hetzner.co.za"]

  spec.summary       = %q{Provides connector, xml and brokerage facilities to a jUDDI consumer}
  spec.description   = %q{Provides connector, xml and brokerage facilities to a jUDDI consumer}
  spec.homepage      = "https://github.com/evangraan/soap4juddi"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ['>=2.0.0']

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'byebug'
#  spec.add_development_dependency 'simplecov', "~> 0.11.1"
#  spec.add_development_dependency 'simplecov-rcov', "~> 0.2.3"

  spec.add_dependency "jsender", "~> 0.2"
end
