require "rollout"
require "roda"
require "mock_redis"

class App < Roda
  route do |r|
    @storage ||= MockRedis.new

    # GET / request
    r.root do
      r.redirect "/main"
    end

    # /main branch
    r.on "main" do
      r.is do
        r.get do

          # Defining channels where the notifications will be sent
          # Slack channel
          SLACK_WEBHOOK_URL = 'YOUR_WEBHOOK_URL'.freeze
          slack_channel = Rollout::Notifications::Channels::Slack.new(
            webhook_url: SLACK_WEBHOOK_URL,
            channel: '#rollout-redis-test-jc'
          )
          # Email channel
          SMTP_HOST = 'YOUR_SMTP_SERVER'.freeze
          email_channel = Rollout::Notifications::Channels::Email.new(
            smtp_host: SMTP_HOST,
            smtp_port: '25',
            from: 'rollout@my-app.com',
            to: 'developers@myteam.com'
          )

          rollout = Rollout.new(@storage)
                      .with_cache
                      .with_degrade(min: 1, threshold: 0.1)
                      .with_notifications(status_change: [slack_channel], degrade: [slack_channel, email_channel])

          activated_feature_flags = []

          msg = "<h1>rollout-redis</h1>"
          msg << "<h2>Testing features</h2>"

          msg << "<p>1. Activating multiple feature flags with different percentages</p>"
          msg << "<ul>"
          feature_flag_name = "my-first-feature-flag"
          activated_feature_flags << feature_flag_name
          msg << "<li>Activating feature flag #{feature_flag_name} with 100% => #{rollout.activate(feature_flag_name)}</li>"
          5.times do |i|
            characters = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
            feature_flag_name = (0...15).map { characters[rand(characters.length)] }.join
            percentage = rand(0...100)

            activated_feature_flags << feature_flag_name

            msg << "<li>Activating feature flag #{feature_flag_name} with #{percentage}% => #{rollout.activate(feature_flag_name, percentage)}</li>"
          end
          feature_flag_name = "my-last-feature-flag"
          msg << "<li>Activating feature flag #{feature_flag_name} with 0% => #{rollout.activate(feature_flag_name, 0)}</li>"
          activated_feature_flags << feature_flag_name
          msg << "</ul>"

          if rollout.active?('my-first-feature-flag')
            msg << "<p>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</p>"
            msg << "<p>xxxxxxxxxxxxxx This code is only visible if my-first-feature-flag FF is active xxxxxxxxxxxxxx</p>"
            msg << "<p>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</p>"
          end

          msg << "<p>2. Listing all the activated feature flags and checking if active for different users:</p>"
          msg << "<ul>"
          user_emails = ['user-email@gmail.com', 'another-user-email@gmail.com', 'super-user-email@gmail.com']
          rollout.features.each do |feature|
            msg << "<li>#{feature[:name]} (#{feature[:percentage]}%). <ul>"
            user_emails.each do |user_email|
              msg << "<li>Active for '#{user_email}'? => #{rollout.active?(feature[:name], user_email)}</li>"
            end
            msg << "</ul></li>"
          end
          msg << "</ul>"

          msg << "<p>3. Checking auto deactivation when error in the released code</p>"
          msg << "<ul>"
          msg << "<li>my-first-feature-flag (100%)<ul>"
          10.times do
            begin
              rollout.with_feature_flag('my-first-feature-flag') do
                raise "My code has an error"
              end
            rescue
            end
          end

          msg << "<li> The feature flag was active, but somehing was wrong performing the released code</li>"
          msg << "<li> Has been auto-deactivated? => #{!rollout.active?('my-first-feature-flag')}</li>"
          msg << "</ul></li></ul>"

          msg
        end
      end
    end
  end
end

run App.freeze.app