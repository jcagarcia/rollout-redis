require_relative 'base'

class Rollout
  module Notifications
    module Notifiers
      class Degrade < Base
        def initialize(channels)
          super(channels)
        end

        def notify(feature_name, requests, errors)
          @channels.each do |c|
            publish_for_slack_channel(c, feature_name, requests, errors) if c.type == :slack
            publish_for_email_channel(c, feature_name, requests, errors) if c.type == :email
          end
        end

        private

        def publish_for_slack_channel(c, feature_name, requests, errors)
          text = "Feature flag '#{feature_name}' has been degraded after #{requests} requests and #{errors} errors"
          c.publish(text)
        end

        def publish_for_email_channel(c, feature_name, requests, errors)
          subject = 'Feature flag has been automatically deactivated!'
          content = "Feature flag '#{feature_name}' has been degraded after #{requests} requests and #{errors} errors"
          c.publish(subject, content)
        end
      end
    end
  end
end