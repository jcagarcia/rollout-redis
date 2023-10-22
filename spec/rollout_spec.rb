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

    context 'when degrade is enable' do
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
        context 'and degrade enabled' do
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

            it 'deactivates the feature flag' do
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
              expect(data).to be nil
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

            it 'does NOT the feature flag' do
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