# rollout-redis ⛳️

[![Gem Version](https://badge.fury.io/rb/rollout-redis.svg)](https://badge.fury.io/rb/rollout-redis)

Fast and easy feature flags based on Redis. 

Based on the discontinued [rollout](https://github.com/fetlife/rollout) project, removing some capabilities, including some new features and supporting latest Redis versions.

Topics covered in this README:

- [Install it](#install-it)
- [Quick Start](#quick-start-💨)
- [Advanced features](#advanced-features-🦾)
  - [Gradual activation based on percentages](#gradual-activation-based-on-percentages)
  - [Caching Feature Flags](#caching-feature-flags)
  - [Auto-deactivating flags](#auto-deactivating-flags)
- [Migrating from rollout gem](#migrating-from-rollout-gem-🚨)
- [Changelog](#changelog)
- [Contributing](#contributing)

## Install it 

```bash
gem install rollout-redis
```

## Quick Start 💨

Instantiate the `Rollout` class sending a `Redis` instance as a parameter.

```ruby
require 'redis'
require 'rollout'

@redis ||= Redis.new(
        host: ENV.fetch('REDIS_HOST'),
        port: ENV.fetch('REDIS_PORT')
      )
@rollout ||= Rollout.new(@redis)
```

Now you can activate Feature Flags:

```ruby
@rollout.activate('FEATURE_FLAG_NAME') # => true/false
```

Verify if a feature is currently enabled:

```ruby
if @rollout.active?('FEATURE_FLAG_NAME')
  # your new code here...
end
```

An alternative to the if check, is to wrap your code under the `with_feature` method. The wrapped code will be performed only if the feature flag is active:

```ruby
@rollout.with_feature('FEATURE_FLAG_NAME') do
  # your new code here...
end
```

If there is an issue, you have the option to disable a feature:

```ruby
@rollout.deactivate('FEATURE_FLAG_NAME')
```

If you want to list all the stored feature flags, you can use the `features` method:

```ruby
@rollout.features
```

The response will be an array of hashes with all the information about the stored feature flags

```ruby
[
  { name: 'a-feature-flag', percentage: 100, data: { requests: 50, errors: 1 } },
  { name: 'another-feature-flag', percentage: 20, data: { requests: 1, errors: 0 } },
  { name: 'super-feature-flag', percentage: 50, data: { requests: 828, errors: 34 } }
]
```

## Advanced features 🦾

### Gradual activation based on percentages

When introducing a new feature, it's a recommended practice to gradually enable it for a specific portion of your target audience to evaluate its impact. To achieve this, you can utilize the `activate` method, as shown below:

```ruby
@rollout.activate('FEATURE_FLAG_NAME', 20)
```

Now, to know if a feature flags is enabled, you need to provide a determinator (in this example, we're using the user email):

```ruby
if @rollout.active?('FEATURE_FLAG_NAME', user_email)
  # your new code here...
end
```

The gradual activation also works wrapping your code within the `with_feature` method, you just need to provde the determinator you want to use.

```ruby
@rollout.with_feature('FEATURE_FLAG_NAME', user_email) do
  # your new code here...
end
```

It's important to note that if you use the `active?` method without specifying a determinator to determine whether this subset of the audience should see the new feature, it will always return `false` since the activation percentage is less than 100%. See:

```ruby
@rollout.activate('FEATURE_FLAG_NAME', 20)
@rollout.active?('FEATURE_FLAG_NAME') # => false
```

### Caching Feature Flags

The Rollout gem is tightly integrated with Redis for feature flag status management. Consequently, occasional connectivity issues between your application and the Redis storage may arise.

To prevent potential application degradation when the Redis storage is unavailable, you can enable feature flag status caching during the gem's instantiation:

```ruby
@rollout ||= Rollout.new(redis).with_cache
```

Additionally, you can specify extra parameters to configure the duration (in seconds) for which the feature flag status is stored in the cache. By default, this duration is set to 300 seconds (5 minutes):

```ruby
@rollout ||= Rollout.new(redis)
              .with_cache(expires_in: 300)
```

In the case that you need to clear the cache at any point, you can make use of the `clean_cache` method:

```ruby
@rollout.clean_cache
```

### Auto-deactivating flags

If you want to allow the gem to deactivate your feature flag automatically when a threshold of erros is reached, you can enable the degrade feature using the `with_degrade` method.

```ruby
@rollout ||= Rollout.new(redis)
              .with_cache
              .with_degrade(sample: 5000, min: 100, threshold: 0.1)
```

So now, instead of using the `active?` method, you need to wrap your new code under the `with_feature` method.

```ruby
@rollout.with_feature('FEATURE_FLAG_NAME') do
  # your new feature code here...
end
```

When any unexpected error appears during the wrapped code execution, the Rollout gem will take it into account for automatically deactivating the feature flag if the threshold of errors is reached. All the managed or captured errors inside the wrapped code will not be taken into consideration.

## Migrating from rollout gem 🚨

If you are currently using the unmaintained [rollout](https://github.com/fetlife/rollout) gem, you should consider checking this [migration guide](https://github.com/jcagarcia/rollout-redis/blob/main/MIGRATING_FROM_ROLLOUT_GEM.md) for start using the new `rollout-redis` gem.

## Changelog

If you're interested in seeing the changes and bug fixes between each version of `rollout-redis`, read the [Changelog](https://github.com/jcagarcia/rollout-redis/blob/main/CHANGELOG.md).

## Contributing

We welcome and appreciate contributions from the open-source community. Before you get started, please take a moment to review the guidelines below.

### How to Contribute

1. Fork the repository.
2. Clone the repository to your local machine.
3. Create a new branch for your contribution.
4. Make your changes and ensure they meet project standards.
5. Commit your changes with clear messages.
6. Push your branch to your GitHub repository.
7. Open a pull request in our repository.
8. Participate in code review and address feedback.
9. Once approved, your changes will be merged.

### Development

This project is dockerized. Once you clone the repository, you can use the `Make` commands to build the project.

```shell
make build
```

You can pass the tests running:

```shell
make test
```

### Issue Tracker

Open issues on the GitHub issue tracker with clear information.

### Contributors

*   Juan Carlos García - Creator - https://github.com/jcagarcia

The `rollout-redis` gem is based on the discontinued [rollout](https://github.com/fetlife/rollout) project, created by [James Golick](https://github.com/jamesgolick)

