require 'spec_helper'

RSpec.describe Rollout do
  class CustomManagedError < StandardError; end

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_FEATURE_FLAG_NAME'}

  after(:each) do
    instance.deactivate(feature_flag_name)
  end

  describe '#with_feature_flag' do
    context 'when the feature flag is fully active' do
      before do
        instance.activate(feature_flag_name)
      end

      it 'performs the block' do
        expected_value = 0
        instance.with_feature_flag(feature_flag_name) do
          expected_value = 1
        end

        expect(expected_value).to eq 1
      end

      context 'and something goes wrong inside the new released code' do
        context 'and global degrade enabled' do
          let(:instance_with_degrade) { instance.with_degrade }

          it 'add a new error count to the feature instance' do
            begin
              instance_with_degrade.with_feature_flag(feature_flag_name) do
                raise 'Error'
              end
            rescue
              data = storage.get(key(feature_flag_name))

              expect(data).to_not be nil
              expect(JSON.parse(data, symbolize_names: true)).to eq({
                errors: 1,
                requests: 1,
                percentage: 100
              })
            end
          end

          context 'when the configured threshold has been reached' do
            let(:instance_with_degrade) do
              instance.with_degrade(min: 100, threshold: 0.5)
            end

            it 'mark the feature flag as degraded' do
              num_of_requests = 101
              num_of_requests.times do |i|
                begin
                  instance_with_degrade.with_feature_flag(feature_flag_name) do
                    raise 'Error' if i.even?
                  end
                rescue
                  data = storage.get(key(feature_flag_name))

                  errors = (i / 2) + 1
                  requests = i + 1
                  if data && requests < num_of_requests
                    expected_data = {
                      errors: errors,
                      requests: requests,
                      percentage: 100
                    }
                    expect(JSON.parse(data, symbolize_names: true)).to eq(expected_data)
                  end
                end
              end

              data = storage.get(key(feature_flag_name))
              expect(JSON.parse(data, symbolize_names: true)).to eq({
                errors: 51,
                requests: 101,
                percentage: 0,
                degraded: true,
                degraded_at: Time.now.to_s
              })
            end
          end

          context 'when the configured threshold has NOT been reached' do
            let(:instance_with_degrade) do
              instance.with_degrade(min: 100, threshold: 0.9)
            end

            it 'does NOT deactivate the feature flag' do
              101.times do |i|
                begin
                  instance_with_degrade.with_feature_flag(feature_flag_name) do
                    raise 'Error' if i.even?
                  end
                rescue
                  data = storage.get(key(feature_flag_name))

                  if data
                    expect(JSON.parse(data, symbolize_names: true)).to eq({
                      errors: (i / 2) + 1,
                      requests: i + 1,
                      percentage: 100
                    })
                  end
                end
              end

              data = storage.get(key(feature_flag_name))
              expect(data).to_not be nil
            end
          end

          context 'when not enough requests to decide' do
            let(:instance_with_degrade) do
              instance.with_degrade(min: 100, threshold: 0.01)
            end

            it 'does NOT degrade the feature flag' do
              99.times do |i|
                begin
                  instance_with_degrade.with_feature_flag(feature_flag_name) do
                    raise 'Error'
                  end
                rescue
                  data = storage.get(key(feature_flag_name))

                  if data
                    expect(JSON.parse(data, symbolize_names: true)).to eq({
                      errors: i + 1,
                      requests: i + 1,
                      percentage: 100
                    })
                  end
                end
              end

              data = storage.get(key(feature_flag_name))
              expect(data).to_not be nil
            end
          end
        end

        context 'and feature flag has degrade configuration' do
          let(:instance) { described_class.new(storage) }
          before do
            instance.activate(feature_flag_name, 100, degrade: { min: 100, threshold: 0.5 })
          end

          it 'add a new error count to the feature instance' do
            begin
              instance.with_feature_flag(feature_flag_name) do
                raise 'Error'
              end
            rescue
              data = storage.get(key(feature_flag_name))

              expect(data).to_not be nil
              expect(JSON.parse(data, symbolize_names: true)).to eq({
                errors: 1,
                requests: 1,
                percentage: 100,
                degrade: {
                  min: 100,
                  threshold: 0.5
                }
              })
            end
          end

          context 'when the configured threshold has been reached' do
            it 'mark the feature flag as degraded' do
              num_of_requests = 101
              num_of_requests.times do |i|
                begin
                instance.with_feature_flag(feature_flag_name) do
                    raise 'Error' if i.even?
                  end
                rescue
                  data = storage.get(key(feature_flag_name))

                  errors = (i / 2) + 1
                  requests = i + 1
                  if data && requests < num_of_requests
                    expected_data = {
                      errors: errors,
                      requests: requests,
                      percentage: 100,
                      degrade: {
                        min: 100,
                        threshold: 0.5
                      }
                    }
                    expect(JSON.parse(data, symbolize_names: true)).to eq(expected_data)
                  end
                end
              end

              data = storage.get(key(feature_flag_name))
              expect(JSON.parse(data, symbolize_names: true)).to eq({
                errors: 51,
                requests: 101,
                percentage: 0,
                degraded: true,
                degraded_at: Time.now.to_s,
                degrade: {
                  min: 100,
                  threshold: 0.5
                }
              })
            end
          end

          context 'when the configured threshold has NOT been reached' do
            it 'does NOT deactivate the feature flag' do
              101.times do |i|
                begin
                  instance.with_feature_flag(feature_flag_name) do
                    raise 'Error' if i % 3 == 0
                  end
                rescue
                  data = storage.get(key(feature_flag_name))

                  if data
                    expect(JSON.parse(data, symbolize_names: true)).to eq({
                      errors: (i / 3) + 1,
                      requests: i + 1,
                      percentage: 100,
                      degrade: {
                        min: 100,
                        threshold: 0.5
                      }
                    })
                  end
                end
              end

              data = storage.get(key(feature_flag_name))
              expect(data).to_not be nil
            end
          end

          context 'when not enough requests to decide' do
            it 'does NOT degrade the feature flag' do
              99.times do |i|
                begin
                instance.with_feature_flag(feature_flag_name) do
                    raise 'Error'
                  end
                rescue
                  data = storage.get(key(feature_flag_name))

                  if data
                    expect(JSON.parse(data, symbolize_names: true)).to eq({
                      errors: i + 1,
                      requests: i + 1,
                      percentage: 100,
                      degrade: {
                        min: 100,
                        threshold: 0.5
                      }
                    })
                  end
                end
              end

              data = storage.get(key(feature_flag_name))
              expect(data).to_not be nil
            end
          end
        end

        context 'and degrade NOT enabled' do
          it 'raises the original error' do
            expect {
              instance.with_feature_flag(feature_flag_name) do
                raise 'Original Error'
              end
            }.to raise_error('Original Error')
          end

          it 'does NOT raise any managed error' do
            expect {
              instance.with_feature_flag(feature_flag_name) do
                begin
                  raise CustomManagedError
                rescue CustomManagedError
                  'Not raise'
                end
              end
            }.to_not raise_error
          end
        end
      end
    end

    context 'when feature flag is only active for a portion of the target' do
      before do
        instance.activate(feature_flag_name, 20)
      end

      context 'and a determinator is NOT provided' do
        it 'does NOT performs the block' do
          expected_value = 0
          instance.with_feature_flag(feature_flag_name) do
            expected_value = 1
          end

          expect(expected_value).to eq 0
        end
      end

      context 'and a determinator is provided' do
        it 'performs the block for the configured portion of the requests' do
          expect((1..100).count do |count|
            instance.with_feature_flag(feature_flag_name, "user#{count}@email.com") do
              true
            end
          end).to be_within(2).of(20)
        end
      end
    end

    context 'when the feature flag is NOT active' do
      it 'does NOT performs the block' do
        expected_value = 0
        instance.with_feature_flag(feature_flag_name) do
          expected_value = 1
        end

        expect(expected_value).to eq 0
      end
    end
  end

  private

  def key(feature_name)
    "feature-rollout-redis:#{feature_name}"
  end
end