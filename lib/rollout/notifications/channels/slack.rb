require 'slack-notifier'

class Rollout
  module Notifications
    module Channels
      class Slack
        def initialize(webhook_url:, channel:, username:'rollout-redis')
          @webhook_url = webhook_url
          @channel = channel
          @username = username
        end

        def publish(text)
          begin
            blocks = [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": text
                }
              }
            ]
            slack_notifier.post(blocks: blocks)
          rescue => e
            puts "[ERROR] Error sending notification to slack webhook. Error => #{e}"
          end
        end

        def type
          :slack
        end

        private

        def slack_notifier
          @notifier ||= ::Slack::Notifier.new @webhook_url do
            defaults channel: @channel,
                     username: @username
          end
        end
      end
    end
  end
end