# Changelog
All changes to `rollout-redis` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.0.0] - 2023-10-25

### Added
- `#with_notifications` method for allowing to send notifications when some different event occurs.

### Changed
- When the threshold of errors is reached when using the `with_degrade` feature, instead of deleting the feature flag from the redis, we are marking it now as degraded, moving the activation percentage to 0% and adding some useful information to the feature flag stored data.

## [0.3.1] - 2023-10-24
- Same as 0.3.0. When testing GitHub actions for moving to first release `1.0.0` it deployed a new version of the gem by error.

## [0.3.0] - 2023-10-24

### Added
- Providing some rake tasks to the consumers of the gem for allowing them to easily manage their feature flags in their applications:
    - `bundle exec rake rollout:on` rake task for activating feature flags
    - `bundle exec rake rollout:off` rake task for deactivating feature flags
    - `bundle exec rake rollout:list` rake task for listing stored feature flags

## [0.2.0] - 2023-10-23

### Added

- `#features` method for listing all the feature flags stored in Redis

## [0.1.0] - 2023-10-23

- Initial version
