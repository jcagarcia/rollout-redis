
namespace :rollout do
  desc "Activate a feature"
  task :on, [:feature, :percentage, :degrade_min, :degrade_threshold] => :environment do |task, args|
    if args.feature
      if args.percentage
        percentage = args.percentage.to_i
      else
        percentage = 100
      end

      if args.degrade_min && args.degrade_threshold
        puts "Activating feature #{args.feature} at #{percentage}% (degrade config set to a min of #{args.degrade_min} requests and a threshold of error of #{args.degrade_threshold.to_f*100}%)..."
        activated = rollout.activate(args.feature, percentage, degrade: { min: args.degrade_min.to_i, threshold: args.degrade_threshold.to_f})
      else
        puts "Activating feature #{args.feature} at #{percentage}%..."
        activated = rollout.activate(args.feature, percentage)
      end

      if activated
        puts "Feature flag #{args.feature} has been activated! :)"
      else
        puts "Feature flag #{args.feature} has NOT been activated! :("
      end
    end
  end

  desc "Deactivate a feature"
  task :off, [:feature] => :environment do |task, args|
    if args.feature
      puts "Deactivating feature #{args.feature}..."
      deactivated = rollout.deactivate(args.feature)
      if deactivated
        puts "Feature flag #{args.feature} has been deactivated! :)"
      else
        puts "Feature flag #{args.feature} has NOT been deactivated! :("
      end
    end
  end

  desc "List features"
  task list: :environment do
    features = rollout.features
    puts "This is the list of all the available features:"
    puts ""
    if !features.empty?
      puts features
    else
      puts "- No feature flags stored"
    end
  end

  desc "Migrate stored feature flags to the new format without removing the old information"
  task migrate_from_rollout_format: :environment do
    puts "Starting the migration..."
    rollout.migrate_from_rollout_format
    puts "Migration has finished!"
  end

  private

  def rollout
    @rollout ||= Rollout.new(storage)
  end

  def storage
    begin
      @storage ||= Redis.new(
        host: ENV.fetch('ROLLOUT_REDIS_HOST'),
        port: ENV.fetch('ROLLOUT_REDIS_PORT')
      )
    rescue KeyError => e
      puts "ROLLOUT_REDIS_HOST and ROLLOUT_REDIS_PORT are mandatory env variables to define in order to run rollout rake tasks"
      raise e
    end
  end
end
