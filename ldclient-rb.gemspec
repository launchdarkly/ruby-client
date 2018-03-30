# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ldclient-rb/version"

# rubocop:disable Metrics/BlockLength
Gem::Specification.new do |spec|
  spec.name          = "ldclient-rb"
  spec.version       = LaunchDarkly::VERSION
  spec.authors       = ["LaunchDarkly"]
  spec.email         = ["team@launchdarkly.com"]
  spec.summary       = "LaunchDarkly SDK for Ruby"
  spec.description   = "Official LaunchDarkly SDK for Ruby"
  spec.homepage      = "https://github.com/launchdarkly/ruby-client"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.extensions    = 'ext/mkrf_conf.rb'

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "codeclimate-test-reporter", "~> 0"
  spec.add_development_dependency "redis", "~> 3.3.5"
  spec.add_development_dependency "connection_pool", ">= 2.1.2"
  spec.add_development_dependency "moneta", "~> 1.0.0"
  if RUBY_VERSION >= "2.0.0"
    spec.add_development_dependency "rspec_junit_formatter", "~> 0.3.0"
  end

  spec.add_runtime_dependency "json", [">= 1.8", "< 3"]
  if RUBY_VERSION >= "2.1.0"
    spec.add_runtime_dependency "faraday", [">= 0.9", "< 2"]
    spec.add_runtime_dependency "faraday-http-cache", [">= 1.3.0", "< 3"]
  else
    spec.add_runtime_dependency "faraday", [">= 0.9", "< 0.14.0"]
    spec.add_runtime_dependency "faraday-http-cache", [">= 1.3.0", "< 2"]
  end
  spec.add_runtime_dependency "semantic", "~> 1.6.0"
  spec.add_runtime_dependency "thread_safe", "~> 0.3"
  spec.add_runtime_dependency "net-http-persistent", "~> 2.9"
  spec.add_runtime_dependency "concurrent-ruby", "~> 1.0.4"
  spec.add_runtime_dependency "hashdiff", "~> 0.2"
  spec.add_runtime_dependency "ld-celluloid-eventsource", "~> 0.11.0"
  spec.add_runtime_dependency "celluloid", "~> 0.18.0.pre" # transitive dep; specified here for more control

  if RUBY_VERSION >= "2.2.2"
    spec.add_runtime_dependency "nio4r", "< 3" # for maximum ruby version compatibility.
  else
    spec.add_runtime_dependency "nio4r", "~> 1.1" # for maximum ruby version compatibility.
  end

  spec.add_runtime_dependency "waitutil", "0.2"
end
