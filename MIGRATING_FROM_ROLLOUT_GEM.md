# Migrating from rollout gem 🚀

In this guide you can find the most important changes and differences between the old rollout gem and this gem.

## Deprecations

In order to simplify the features of the first versions of the gem, the following capabilities have been removed:

- Users and groups management have been replaced with a determinator when checking if the feature flag is active or not.
- The ability of changing the information stored inside a feature flag.
- The ability of geting the internal information of a stored feature flag.
- `#features` method does not return anymore a string with the feature names separated by comma. Now it returns an array of hashes.

This is the complete list of methods that have been removed: `#groups`, `#delete`, `#set`, `#activate_group`, `#deactivate_group`, `#activate_user`, `#deactivate_user`, `#activate_users`, `#deactivate_users`, `#set_users`, `#define_group`, `#user_in_active_users?`, `#inactive?`, `#deactivate_percentage`, `active_in_group?`, `#get`, `#set_feature_data`, `#clear_feature_data`, `#multi_get`, `#feature_states`, `#active_features`, `#clear!`, `#exists?`, `#with_feature`.

If you consider some of these methods or features 👆 should be added again to the gem, please, open an issue and we will evaluate it.

## New methods 🎁

New methods has been added: `#with_cache`, `#with_degrade`, `#with_feature_flag`, `#clean_cache`.

## Important changes 🚨

### Keys format and stored data has been changed 🔑

The old [rollout](https://github.com/fetlife/rollout) gem is storing the features flags using `feature:#{name}` as key format. The stored value for each feature flag is a string with this format: `percentage|users|groups|data`. This an example of a current flag stored in redis:

```
Key: "feature:my-feature-flag"
Value: "100|||{}"
```

We have decided to store the data of each feature flag in a more understandable way, so as we don't want to collision with your current stored feature flags this new gem is using `feature-rollout-redis:#{name}` as namespace for storing the new feature flag names in redis.

_NOTE_: This mean that any of your current active feature flags will be taken into consideration!!!

Also, the stored information has been changed and now is a JSON:

```json
{
    "percentage": 100,
    "requests": 0,
    "errors": 0
}
```

#### Migrating feature flags

In order to facilitate the migration, we are offering a method for easily move from the old format to the new one.

```ruby
@rollout.migrate_from_rollout_format
```

This method will NOT remove your old stored feature flags. It will just perform a migration.

Take into consideration that as we are removing users and groups capabilities, you will lost that information after performing the migration. If you want to keep that information, we encourage you to build your own method/script for performing the migration.