require 'mock_redis'
require 'rake'
require 'rollout'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
      c.syntax = :expect
  end

  config.order = :random
end