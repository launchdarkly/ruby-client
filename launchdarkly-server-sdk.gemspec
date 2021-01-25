# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ldclient-rb/version"

# rubocop:disable Metrics/BlockLength
Gem::Specification.new do |spec|
  spec.name          = "launchdarkly-server-sdk"
  spec.version       = LaunchDarkly::VERSION
  spec.authors       = ["LaunchDarkly"]
  spec.email         = ["team@launchdarkly.com"]
  spec.summary       = "LaunchDarkly SDK for Ruby"
  spec.description   = "Official LaunchDarkly SDK for Ruby"
  spec.homepage      = "https://github.com/launchdarkly/ruby-server-sdk"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.5.0"

  spec.add_development_dependency "aws-sdk-dynamodb", "~> 1.57"
  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "diplomat", "~> 2.4.2"
  spec.add_development_dependency "redis", "~> 4.2"
  spec.add_development_dependency "connection_pool", "~> 2.2.3"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.4"
  spec.add_development_dependency "timecop", "~> 0.9"
  spec.add_development_dependency "listen", "~> 3.3" # see file_data_source.rb
  spec.add_development_dependency "webrick", "~> 1.7"
  # required by dynamodb
  spec.add_development_dependency "oga", "~> 2.2"

  spec.add_runtime_dependency "semantic", "~> 1.6"
  spec.add_runtime_dependency "concurrent-ruby", "~> 1.1"
  spec.add_runtime_dependency "ld-eventsource", "2.0.0.pre.beta.1"

  # lock json to 2.3.x as ruby libraries often remove
  # support for older ruby versions in minor releases
  spec.add_runtime_dependency "json", "~> 2.3.1"
  spec.add_runtime_dependency "http", "~> 4.4.1"
end
