require 'spec_helper'

RSpec.describe Rollout do

  let(:storage) { MockRedis.new }
  let(:instance) { described_class.new(storage)}
  let(:feature_flag_name) { 'A_FEATURE_FLAG_NAME'}

  let(:slack_channel) do
    Rollout::Notifications::Channels::Slack.new(webhook_url: 'a-url', channel: '#my-channel')
  end
  let(:email_channel) do
    Rollout::Notifications::Channels::Email.new(smtp_host: 'localhost', smtp_port: '587', to: 'developers@mycompany.com')
  end

  describe '#with_notifications' do
    let(:channels) do
      [
        slack_channel,
        email_channel
      ]
    end

    context 'when status_change event has channels defined' do
      let(:instance_with_notifications) do
        instance.with_notifications(status_change: channels)
      end

      context 'when new feature flag is activated' do
        it 'sends the notification to the defined channels' do
          feature_flag_name = 'a-feature-flag'
          percentage = 87

          expected_subject = "Feature flag has been activated!"
          expected_message = "Feature flag '#{feature_flag_name}' has been activated with percentage #{percentage}!"

          expect(slack_channel).to receive(:publish).with(expected_message)
          expect(email_channel).to receive(:publish).with(expected_subject, expected_message)

          instance_with_notifications.activate(feature_flag_name, percentage)
        end
      end

      context 'when a feature flag is deactivated' do
        it 'sends the notification to the defined channels' do
          feature_flag_name = 'a-feature-flag'

          expected_subject = "Feature flag has been deactivated!"
          expected_message = "Feature flag '#{feature_flag_name}' has been deactivated and deleted!"

          expect(slack_channel).to receive(:publish).with(expected_message)
          expect(email_channel).to receive(:publish).with(expected_subject, expected_message)

          instance_with_notifications.deactivate(feature_flag_name)
        end
      end

      context 'when migrating from the old rollout gem format' do
        context 'when the existing feature flag is active' do
          before do
            storage.set("feature:old-key", "100|||{}")
          end

          it 'sends the proper notifications to the defined channels' do
            expected_subject = "Feature flag has been activated!"
            expected_message = "Feature flag 'old-key' has been activated with percentage 100!"
  
            expect(slack_channel).to receive(:publish).with(expected_message)
            expect(email_channel).to receive(:publish).with(expected_subject, expected_message)

            instance_with_notifications.migrate_from_rollout_format
          end
        end
      end
    end

    context 'when degrade event has channels defined' do
      context 'when the instance is configured for degrading feature flags' do
        let(:instance_with_degrade_and_notifications) do
          instance
            .with_degrade(min: 100, threshold: 0.5)
            .with_notifications(degrade: channels)
        end
  
        context 'and a feature flag reaches the threshold of errors' do
          it 'sends the degraded notification to the defined channels' do
            feature_flag_name = 'a-feature-flag'
            instance_with_degrade_and_notifications.activate(feature_flag_name)

            expected_subject = "Feature flag has been automatically deactivated!"
            expected_message = "Feature flag '#{feature_flag_name}' has been degraded after 101 requests and 51 errors"
  
            expect(slack_channel).to receive(:publish).with(expected_message)
            expect(email_channel).to receive(:publish).with(expected_subject, expected_message)

            101.times do |i|
              begin
                instance_with_degrade_and_notifications.with_feature_flag(feature_flag_name) do
                  raise "error" if i.even?
                end
              rescue
              end
            end
          end
        end 
      end
    end
  end
end