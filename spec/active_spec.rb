require 'spec_helper'

RSpec.describe Rollout do
  class CustomManagedError < StandardError; end

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_FEATURE_FLAG_NAME'}

  after(:each) do
    instance.deactivate(feature_flag_name)
  end

  describe '#active?' do
    context 'when feature flag is fully active' do
      before do
        instance.activate(feature_flag_name)
      end

      it 'returns true' do
        result = instance.active?(feature_flag_name)
  
        expect(result).to be true
      end
    end

    context 'when feature flag is only active for a portion of the target' do
      before do
        instance.activate(feature_flag_name, 20)
      end

      it 'return true for the configured portion of the requests' do
        expect((1..100).count do |count|
          instance.active?(feature_flag_name, "user#{count}@email.com")
        end).to be_within(2).of(20)
      end

      it 'returns false for at least the other portion of the requests' do
        expect((1..100).count do |count|
          !instance.active?(feature_flag_name, "user#{count}@email.com")
        end).to be_within(2).of(80)
      end
    end

    context 'when feature flag is NOT active' do
      it 'returns false' do
        result = instance.active?(feature_flag_name)
  
        expect(result).to be false
      end
    end

    context 'when global degrade is enable' do
      let(:instance_with_degrade) { instance.with_degrade }

      context 'and the feature flag is enabled' do
        before do
          instance.activate(feature_flag_name)
        end

        it 'stores the number of requests' do
          33.times do
            instance_with_degrade.active?(feature_flag_name)
          end

          data = storage.get(key(feature_flag_name))

          expect(data).to_not be nil
          expect(JSON.parse(data, symbolize_names: true)).to eq({
            percentage: 100,
            requests: 33
          })
        end
      end
    end

    context 'when degrade is enable for the specific feature flag' do
      context 'and the feature flag is enabled' do
        let(:instance) { described_class.new(storage) }
        before do
          instance.activate(feature_flag_name, 100, degrade: { min: 100, threshold: 0.5 })
        end

        it 'stores the number of requests' do
          101.times do
            instance.active?(feature_flag_name)
          end

          data = storage.get(key(feature_flag_name))

          expect(data).to_not be nil
          expect(JSON.parse(data, symbolize_names: true)).to eq({
            percentage: 100,
            requests: 101,
            degrade: {
              min: 100,
              threshold: 0.5
            }
          })
        end
      end
    end

    context 'when redis not available' do
      context 'and cache NOT enabled' do
        it 'raises a Rollout::Error' do
          allow(storage).to receive(:get).and_raise(::Redis::BaseError)

          expect {
            instance.active?(feature_flag_name)
          }.to raise_error(Rollout::Error)
        end
      end

      context 'and cache enabled' do
        let(:instance_with_cache) { instance.with_cache }

        context 'and the feature flag was cached before' do
          before do
            instance_with_cache.activate(feature_flag_name)
          end

          context 'and not expired' do
            context 'and the feature flag was fully enabled' do
              it 'returns true' do
                allow(storage).to receive(:get).and_raise(::Redis::BaseError)
                result = instance_with_cache.active?(feature_flag_name)

                expect(result).to be true
              end
            end

            context 'and the feature flag was only active for a portion of the target' do
              before do
                instance_with_cache.activate(feature_flag_name, 20)
              end

              it 'return true for the configured portion of the requests' do
                allow(storage).to receive(:get).and_raise(::Redis::BaseError)
                expect((1..100).count do |count|
                  instance_with_cache.active?(feature_flag_name, "user#{count}@email.com")
                end).to be_within(2).of(20)
              end
        
              it 'returns false for at least the other portion of the requests' do
                allow(storage).to receive(:get).and_raise(::Redis::BaseError)
                expect((1..100).count do |count|
                  !instance_with_cache.active?(feature_flag_name, "user#{count}@email.com")
                end).to be_within(2).of(80)
              end
            end
          end

          context 'but expired' do
            let(:instance_with_cache) { instance.with_cache(expires_in: 1) }

            before do
              allow(Time).to receive(:now).and_return(Time.now + 2)
            end

            it 'raises a Rollout::Error' do
              allow(storage).to receive(:get).and_raise(::Redis::BaseError)

              expect {
                instance_with_cache.active?(feature_flag_name)
              }.to raise_error(Rollout::Error)
            end
          end
        end
      end
    end
  end

  private

  def key(feature_name)
    "feature-rollout-redis:#{feature_name}"
  end
end