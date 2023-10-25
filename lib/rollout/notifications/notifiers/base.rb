class Rollout
  module Notifications
    module Notifiers
      class Base
        def initialize(channels)
          if channels.respond_to?(:first)
            @channels = channels
          else
            @channels = [channels]
          end
        end
      end
    end
  end
end