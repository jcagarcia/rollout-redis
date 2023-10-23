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
    Rake.application.invoke_task "rollout:on[super-feature-flag,50]"

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

    output = rake_output.string
    expect(output).to include('Activating feature a-feature-flag...')
    expect(output).to include('Feature flag a-feature-flag has been activated! :)')
    expect(output).to include('Activating feature another-feature-flag...')
    expect(output).to include('Feature flag another-feature-flag has been activated! :)')
    expect(output).to include('Activating feature super-feature-flag...')
    expect(output).to include('Feature flag super-feature-flag has been activated! :)')
    expect(output).to include('This is the list of all the available features:')
    expect(output).to include('{:name=>"a-feature-flag", :percentage=>100, :data=>{:requests=>0, :errors=>0}}')
    expect(output).to include('{:name=>"another-feature-flag", :percentage=>20, :data=>{:requests=>0, :errors=>0}}')
    expect(output).to include('{:name=>"super-feature-flag", :percentage=>50, :data=>{:requests=>0, :errors=>0}}')
    expect(output).to include('Deactivating feature a-feature-flag...')
    expect(output).to include('Feature flag a-feature-flag has been deactivated! :)')
    expect(output).to include('Deactivating feature another-feature-flag...')
    expect(output).to include('Feature flag another-feature-flag has been deactivated! :)')
    expect(output).to include('Deactivating feature super-feature-flag...')
    expect(output).to include('Feature flag super-feature-flag has been deactivated! :)')
    expect(output).to include('This is the list of all the available features:')
    expect(output).to include('- No feature flags stored')
  end
end