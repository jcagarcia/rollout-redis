# Migrating from rollout gem 🚀

In this guide you can find the most important changes and differences between the old rollout gem and this gem.

- [Deprecations](#deprecations)
- [New methods](#new-methods-)
- [Important Changes](#important-changes-)
  - [Keys format and stored data has been changed](#keys-format-and-stored-data-has-been-changed-)
    - [Migrating Feature Flags](#migrating-feature-flags)
    - [Make the gem compatible](#make-the-gem-compatible)

## Deprecations

In order to simplify the features of the first versions of the gem, the following capabilities have been removed:

- Users and groups management have been replaced with a determinator when checking if the feature flag is active or not.
- The ability of changing the information stored inside a feature flag.
- The ability of geting the internal information of a stored feature flag.
- `#features` method does not return anymore a string with the feature names separated by comma. Now it returns an array of hashes.

This is the complete list of methods that have been removed: `#groups`, `#delete`, `#set`, `#activate_group`, `#deactivate_group`, `#activate_user`, `#deactivate_user`, `#activate_users`, `#deactivate_users`, `#set_users`, `#define_group`, `#user_in_active_users?`, `#inactive?`, `#deactivate_percentage`, `active_in_group?`, `#get`, `#set_feature_data`, `#clear_feature_data`, `#multi_get`, `#feature_states`, `#active_features`, `#clear!`, `#exists?`, `#with_feature`.

If you consider some of these 👆 methods or features should be added again to the gem, please, open an discussion and we will evaluate it.

## New methods 🎁

New methods has been added: `#with_cache`, `#with_degrade`, `#with_feature_flag`, `#clean_cache`, `#with_notifications`.

## Important changes 🚨

### Keys format and stored data has been changed 🔑

The old [rollout](https://github.com/fetlife/rollout) gem is storing the features flags using `feature:#{name}` as key format. The stored value for each feature flag is a string with this format: `percentage|users|groups|data`. This an example of a feature flag stored in redis by the **old** `rollout` gem:

```
Key: "feature:my-feature-flag"
Value: "100|||{}"
```

We have decided to store the data of each feature flag in a more understandable way so, as we don't want to collision with your current stored feature flags, our new gem is using `feature-rollout-redis:#{name}` as namespace for storing the new feature flag names in redis.

Also, the stored information has been changed and now is a JSON:

```json
{
    "percentage": 100,
    "requests": 0,
    "errors": 0
}
```

This mean that any of your current active feature flags will NOT be taken into consideration when asking if `#active?`!!!

If you want to keep working with your current feature flags, you have two options:

#### Migrating feature flags

If you decide to fully go with the new `rollout-redis` gem structure, we are offering a method for easily move from the old format to the new one.

```ruby
@rollout.migrate_from_rollout_format
```

This method will NOT remove your old stored feature flags. It will just perform a migration.

Also, we are offering a rake task for performing this method in an easy way before start using the new gem.

```shell
bundle exec rake rollout:migrate_from_rollout_format
```

Take into consideration that as we are removing users and groups capabilities, you will lost that information after performing the migration. If you want to keep that information, we encourage you to build your own method/script for performing the migration.

#### Make the gem compatible

However, if you want to keep your old feature flags stored in your Redis, you can configure the `Rollout` instance for checking them. So when using the `#active?` method or the `#with_feature_flag` merhod, if the feature flag does not exist using the new key format, we will check the old format and if exists:

1. We will parse the content to match the new format
2. If enabled, we will automatically store it in the new format to do a gradual migration.
3. We will return if the requested feature flag is active or not.

For doing that, you can use the `#with_old_rollout_gem_compatibility` instance method when creating the rollout instance:

```ruby
@rollout ||= Rollout.new(@storage)
              .with_cache
              .with_degrade
              .with_old_rollout_gem_compatibility(auto_migration: true)
```

