require 'spec_helper'

RSpec.describe Rollout do
  class CustomManagedError < StandardError; end

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_FEATURE_FLAG_NAME'}

  after(:each) do
    instance.deactivate(feature_flag_name)
  end

  describe '#features' do
    context 'when no feature flags stored' do
      it 'returns empty list' do
        result = instance.features

        expect(result).to eq([])
      end
    end

    context 'when there are feature flags stored' do
      before do
        instance.activate('a-feature-flag')
        instance.activate('another-feature-flag', 20)
        instance.activate('super-feature-flag', 50)
      end

      it 'returns the list of features' do
        result = instance.features

        expect(result).to eq([
          {
            name: 'a-feature-flag',
            percentage: 100,
            data: {
              requests: 0,
              errors: 0
            }
          },
          {
            name: 'another-feature-flag',
            percentage: 20,
            data: {
              requests: 0,
              errors: 0
            }
          },
          {
            name: 'super-feature-flag',
            percentage: 50,
            data: {
              requests: 0,
              errors: 0
            }
          }
        ])
      end

      context 'and their information has been updated after making requests' do
        let(:instance_with_degrade) { instance.with_degrade }

        before do
          instance_with_degrade.activate('a-feature-flag')
          instance_with_degrade.activate('another-feature-flag')
          instance_with_degrade.activate('super-feature-flag')

          50.times do
            begin
              instance_with_degrade.with_feature_flag('a-feature-flag') do
                raise "Error"
              end
            rescue
            end
            instance_with_degrade.active?('another-feature-flag')
            instance_with_degrade.active?('super-feature-flag')
          end
        end

        it 'returns the list of features with the updated requests and errors' do
          result = instance_with_degrade.features

          expect(result).to eq([
            {
              name: 'a-feature-flag',
              percentage: 100,
              data: {
                requests: 50,
                errors: 50
              }
            },
            {
              name: 'another-feature-flag',
              percentage: 100,
              data: {
                requests: 50,
                errors: 0
              }
            },
            {
              name: 'super-feature-flag',
              percentage: 100,
              data: {
                requests: 50,
                errors: 0
              }
            }
          ])
        end
      end
    end
  end
end