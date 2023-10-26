require 'spec_helper'

RSpec.describe "Rake tasks" do
  let(:storage) { MockRedis.new }
  let(:instance) { Rollout.new(storage) }
  let(:redis_host) { 'localhost' }
  let(:redis_port) { '6379' }
  let!(:original_stdout) { $stdout }
  let(:rake_output) { StringIO.new }

  before(:each) do
    $stdout = rake_output
    allow(Redis).to receive(:new).with(host: redis_host, port: redis_port).and_return(storage)
    ENV["ROLLOUT_REDIS_HOST"] = redis_host
    ENV["ROLLOUT_REDIS_PORT"] = redis_port

    store_feature_flags_in_old_format
  end

  after(:each) do
    $stdout = original_stdout
  end

  it "performs all the operations" do
    Rake.application.rake_require "rollout/tasks/rollout"
    Rake::Task.define_task(:environment)

    Rake::Task["rollout:on"].reenable
    Rake.application.invoke_task "rollout:on[a-feature-flag]"
    Rake::Task["rollout:on"].reenable
    Rake.application.invoke_task "rollout:on[another-feature-flag,20]"
    Rake::Task["rollout:on"].reenable
    Rake.application.invoke_task "rollout:on[super-feature-flag,50,500,0.1]"

    expect(instance.active?('a-feature-flag')).to be true
    expect(instance.active?('another-feature-flag')).to be false
    expect(instance.active?('super-feature-flag')).to be false

    Rake::Task["rollout:list"].reenable
    Rake.application.invoke_task "rollout:list"

    Rake::Task["rollout:off"].reenable
    Rake.application.invoke_task "rollout:off[a-feature-flag]"
    Rake::Task["rollout:off"].reenable
    Rake.application.invoke_task "rollout:off[another-feature-flag]"
    Rake::Task["rollout:off"].reenable
    Rake.application.invoke_task "rollout:off[super-feature-flag]"

    expect(instance.active?('a-feature-flag')).to be false
    expect(instance.active?('another-feature-flag')).to be false
    expect(instance.active?('super-feature-flag')).to be false

    Rake::Task["rollout:list"].reenable
    Rake.application.invoke_task "rollout:list"

    Rake::Task["rollout:list"].reenable
    Rake.application.invoke_task "rollout:migrate_from_rollout_format"

    output = rake_output.string
    expect(output).to include('Activating feature a-feature-flag at 100%...')
    expect(output).to include('Feature flag a-feature-flag has been activated! :)')
    expect(output).to include('Activating feature another-feature-flag at 20%...')
    expect(output).to include('Feature flag another-feature-flag has been activated! :)')
    expect(output).to include('Activating feature super-feature-flag at 50% (degrade config set to a min of 500 requests and a threshold of error of 10.0%)...')
    expect(output).to include('Feature flag super-feature-flag has been activated! :)')
    expect(output).to include('This is the list of all the available features:')
    expect(output).to include('{:name=>"a-feature-flag", :percentage=>100, :data=>{:requests=>0, :errors=>0}}')
    expect(output).to include('{:name=>"another-feature-flag", :percentage=>20, :data=>{:requests=>0, :errors=>0}}')
    expect(output).to include('{:name=>"super-feature-flag", :percentage=>50, :data=>{:requests=>0, :errors=>0}, :degrade=>{:min=>500, :threshold=>0.1}}')
    expect(output).to include('Deactivating feature a-feature-flag...')
    expect(output).to include('Feature flag a-feature-flag has been deactivated! :)')
    expect(output).to include('Deactivating feature another-feature-flag...')
    expect(output).to include('Feature flag another-feature-flag has been deactivated! :)')
    expect(output).to include('Deactivating feature super-feature-flag...')
    expect(output).to include('Feature flag super-feature-flag has been deactivated! :)')
    expect(output).to include('This is the list of all the available features:')
    expect(output).to include('- No feature flags stored')
    expect(output).to include('Starting the migration...')
    expect(output).to include('Migrated redis key from feature:old-key-1 to feature-rollout-redis:old-key-1. Migrating data from \'100|||{ \'random\': \'data\' }\' to \'{"percentage":100,"requests":0,"errors":0}\'.')
    expect(output).to include('Migrated redis key from feature:old-key-2 to feature-rollout-redis:old-key-2. Migrating data from \'50|user1#user2||{}\' to \'{"percentage":50,"requests":0,"errors":0}\'.')
    expect(output).to include('Migrated redis key from feature:old-key-3 to feature-rollout-redis:old-key-3. Migrating data from \'25||group22|{}\' to \'{"percentage":25,"requests":0,"errors":0}\'.')
    expect(output).to include('Migrated redis key from feature:old-key-4 to feature-rollout-redis:old-key-4. Migrating data from \'30|user1|general|{}\' to \'{"percentage":30,"requests":0,"errors":0}\'.')
    expect(output).to include('Migration has finished!')
  end

  def store_feature_flags_in_old_format
    storage.set("feature:old-key-1", "100|||{ 'random': 'data' }")
    storage.set("feature:old-key-2", "50|user1#user2||{}")
    storage.set("feature:old-key-3", "25||group22|{}")
    storage.set("feature:old-key-4", "30|user1|general|{}")
  end
end