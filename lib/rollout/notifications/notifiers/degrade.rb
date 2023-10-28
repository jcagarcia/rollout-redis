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
            if c.class == Rollout::Notifications::Channels::Email
              publish_to_email_channel(c, feature_name, requests, errors)
            else
              publish_to_channel(c, feature_name, requests, errors)
            end
          end
        end

        private

        def publish_to_channel(c, feature_name, requests, errors)
          text = "Feature flag '#{feature_name}' has been degraded after #{requests} requests and #{errors} errors"
          c.publish(text)
        end

        def publish_to_email_channel(c, feature_name, requests, errors)
          subject = 'Feature flag has been automatically deactivated!'
          content = "Feature flag '#{feature_name}' has been degraded after #{requests} requests and #{errors} errors"
          c.publish(subject, content)
        end
      end
    end
  end
end