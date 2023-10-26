require 'spec_helper'

RSpec.describe Rollout do
  class CustomManagedError < StandardError; end

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_FEATURE_FLAG_NAME'}

  after(:each) do
    instance.deactivate(feature_flag_name)
  end

  describe '#deactivate' do
    before(:each) do
      instance.activate(feature_flag_name)
    end

    it 'returns true' do
      result = instance.deactivate(feature_flag_name)

      expect(result).to be true
    end

    it 'removes the feature from the storage' do
      data = storage.get(key(feature_flag_name))
      expect(data).to_not be nil
      instance.deactivate(feature_flag_name)
      data = storage.get(key(feature_flag_name))

      expect(data).to be nil
    end
  end

  private

  def key(feature_name)
    "feature-rollout-redis:#{feature_name}"
  end
end