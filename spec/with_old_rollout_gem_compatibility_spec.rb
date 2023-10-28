require 'spec_helper'

RSpec.describe Rollout do

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_OLD_FEATURE_FLAG'}

  describe '#with_old_rollout_gem_compatibility' do
    context 'when the requested feature flag was stored by the old rollout gem' do
      context 'and the feature flag was fully activated' do
        before(:each) do
          storage.set(old_key(feature_flag_name), "100|||{}")
        end

        context 'and the instance is properly configured for working with old formats' do
          it 'returns true' do
            expect(described_class.new(storage).with_old_rollout_gem_compatibility.active?(feature_flag_name)).to be true
          end

          context 'and auto_migration is configured' do
            let(:feature_flag_name) { 'a-feature-flag-that-will-be-auto-migrated' }
            it 'stores a new key with the new format' do
              expect(instance.active?(feature_flag_name)).to be false
              described_class.new(storage).with_old_rollout_gem_compatibility(auto_migration: true).active?(feature_flag_name)
              expect(instance.active?(feature_flag_name)).to be true
            end
          end

          context 'and auto_migration is NOT configured' do
            let(:feature_flag_name) { 'a-feature-flag-that-will-not-be-auto-migrated' }
            it 'does NOT store a new key using the new format' do
              expect(instance.active?(feature_flag_name)).to be false
              described_class.new(storage).with_old_rollout_gem_compatibility(auto_migration: false).active?(feature_flag_name)
              expect(instance.active?(feature_flag_name)).to be false
            end
          end
        end

        context 'and the instance is not configured for working with old formats' do
          it 'returns false' do
            expect(instance.active?(feature_flag_name)).to be false
          end
        end
      end

      context 'and the feature flag was not fully activated' do
        before do
          storage.set(old_key(feature_flag_name), "50|||{}")
        end

        context 'and a determinator is passed' do
          it 'returns true for some determinators and false for others' do
            expect(described_class.new(storage).with_old_rollout_gem_compatibility.active?(feature_flag_name, 'a-determinator')).to be true
            expect(described_class.new(storage).with_old_rollout_gem_compatibility.active?(feature_flag_name, 'an-determinator')).to be false
          end
        end

        context 'and a determinator is NOT passed' do
          it 'returns false' do
            expect(instance.active?(feature_flag_name)).to be false
            expect(described_class.new(storage).with_old_rollout_gem_compatibility.active?(feature_flag_name)).to be false
          end
        end
      end
    end
  end

  def old_key(feature_name)
    "feature:#{feature_name}"
  end
end