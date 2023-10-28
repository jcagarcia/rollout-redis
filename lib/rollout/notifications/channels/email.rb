require 'mail'

class Rollout
  module Notifications
    module Channels
      class Email
        def initialize(smtp_host:, smtp_port:, from:'no-reply@rollout-redis.com', to:)
          @smtp_host = smtp_host
          @smtp_port = smtp_port
          @from = from
          @to = to
        end

        def publish(subject, body)
          mail = Mail.new do
            subject  subject
            body     body
          end
          mail.smtp_envelope_from = @from
          mail.smtp_envelope_to = @to
          mail.delivery_method :smtp, address: @smtp_host, port: @smtp_port
          mail.deliver
        end
      end
    end
  end
end 