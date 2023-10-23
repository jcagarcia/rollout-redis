
namespace :rollout do
  desc "Activate a feature"
  task :on, [:feature, :percentage] => :environment do |task, args|
    if args.feature
      puts "Activating feature #{args.feature}..."
      if args.percentage
        activated = rollout.activate(args.feature, args.percentage.to_i)
      else
        activated = rollout.activate(args.feature)
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
