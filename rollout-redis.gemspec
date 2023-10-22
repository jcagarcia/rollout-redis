# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'rollout/version'

Gem::Specification.new do |spec|
  spec.name        = 'rollout-redis'
  spec.version     = Rollout::VERSION
  spec.authors     = ['Juan Carlos García']
  spec.email       = ['jugade92@gmail.com']
  spec.description = 'Fast and easy feature flags based on the latest Redis versions.'
  spec.summary     = 'Fast and easy feature flags based on the latest Redis versions.'
  spec.homepage    = 'https://github.com/jcagarcia/rollout-redis'
  spec.license     = 'MIT'

  files = Dir["lib/**/*.rb", "lib/**/tasks/*.rake"]
  rootfiles = ["CHANGELOG.md", "rollout-redis.gemspec", "Rakefile", "README.md"]

  spec.files = rootfiles + files
  spec.executables = []
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.3'

  spec.add_runtime_dependency 'redis', '>= 4.0', '<= 5'

  spec.add_development_dependency 'bundler', '>= 2.4'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'mock_redis', '~> 0.37'
end