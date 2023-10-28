require_relative 'base'

class Rollout
  module Notifications
    module Notifiers
      class StatusChange < Base
        def initialize(channels)
          super(channels)
        end

        def notify(feature_name, new_status, new_percentage=nil)
          @channels.each do |c|
            if c.class == Rollout::Notifications::Channels::Email
              publish_to_email_channel(c, feature_name, new_status, new_percentage)
            else
              publish_to_channel(c, feature_name, new_status, new_percentage)
            end
          end
        end

        private

        def publish_to_channel(c, feature_name, new_status, new_percentage)
          if new_status == :activated
            text = "Feature flag '#{feature_name}' has been activated with percentage #{new_percentage}!"
          elsif new_status == :deactivated
            text = "Feature flag '#{feature_name}' has been deactivated and deleted!"
          end
          c.publish(text)
        end

        def publish_to_email_channel(c, feature_name, new_status, new_percentage)
          if new_status == :activated
            subject = 'Feature flag has been activated!'
            content = "Feature flag '#{feature_name}' has been activated with percentage #{new_percentage}!"
          elsif new_status == :deactivated
            subject = 'Feature flag has been deactivated!'
            content = "Feature flag '#{feature_name}' has been deactivated and deleted!"
          end
          c.publish(subject, content)
        end
      end
    end
  end
end