require 'spec_helper'

RSpec.describe Rollout do
  class CustomManagedError < StandardError; end

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_FEATURE_FLAG_NAME'}

  after(:each) do
    instance.deactivate(feature_flag_name)
  end

  describe '#migrate_from_rollout_format' do
    before do
      storage.set(old_key(feature_flag_name), "100|||{}")
    end

    it 'migrates the old keys to the new format' do
      expect(instance.active?(feature_flag_name)).to be false

      instance.migrate_from_rollout_format

      expect(instance.active?(feature_flag_name)).to be true
    end
  end

  private

  def key(feature_name)
    "feature-rollout-redis:#{feature_name}"
  end

  def old_key(feature_name)
    "feature:#{feature_name}"
  end
end