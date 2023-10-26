require 'spec_helper'

RSpec.describe Rollout do
  class CustomManagedError < StandardError; end

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_FEATURE_FLAG_NAME'}

  after(:each) do
    instance.deactivate(feature_flag_name)
  end

  describe '#activate' do
    it 'returns true' do
      result = instance.activate(feature_flag_name)

      expect(result).to be true
    end

    it 'stores the proper info in the redis storage' do
      instance.activate(feature_flag_name)
      data = storage.get(key(feature_flag_name))

      expect(data).to_not be nil
      expect(JSON.parse(data, symbolize_names: true)).to eq({
        percentage: 100
      })
    end

    context 'when a percentage of activation is passed' do
      it 'returns true' do
        result = instance.activate(feature_flag_name, 20)

        expect(result).to be true
      end

      it 'stores the proper info in the redis storage' do
        instance.activate(feature_flag_name, 20)
        data = storage.get(key(feature_flag_name))

        expect(data).to_not be nil
        expect(JSON.parse(data, symbolize_names: true)).to eq({
          percentage: 20
        })
      end
    end

    context 'when degrade configuration is passed' do
      it 'returns true' do
        result = instance.activate(feature_flag_name, 20, degrade: { min: 100, threshold: 0.5 })

        expect(result).to be true
      end

      it 'stores the proper info in the redis storage' do
        instance.activate(feature_flag_name, 20, degrade: { min: 100, threshold: 0.5 })
        data = storage.get(key(feature_flag_name))

        expect(data).to_not be nil
        expect(JSON.parse(data, symbolize_names: true)).to eq({
          percentage: 20,
          degrade: {
            min: 100,
            threshold: 0.5
          }
        })
      end
    end
  end

  private

  def key(feature_name)
    "feature-rollout-redis:#{feature_name}"
  end
end