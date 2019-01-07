# Change log

All notable changes to the LaunchDarkly Ruby SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

## [5.4.2] - 2019-01-04
### Fixed:
- Fixed overly specific dependency versions of `concurrent-ruby` and `semantic`. ([#115](https://github.com/launchdarkly/ruby-client/issues/115))
- Removed obsolete dependencies on `hashdiff` and `thread_safe`.

## [5.4.1] - 2018-11-05
### Fixed:
- Fixed a `LoadError` in `file_data_source.rb`, which was added in 5.4.0. (Thanks, [kbarrette](https://github.com/launchdarkly/ruby-client/pull/110)!)


## [5.4.0] - 2018-11-02
### Added:
- It is now possible to inject feature flags into the client from local JSON or YAML files, replacing the normal LaunchDarkly connection. This would typically be for testing purposes. See `file_data_source.rb`.

### Fixed:
- When shutting down an `LDClient`, if in polling mode, the client was using `Thread.raise` to make the polling thread stop sleeping. `Thread.raise` can cause unpredictable behavior in a worker thread, so it is no longer used.

## [5.3.0] - 2018-10-24
### Added:
- The `all_flags_state` method now accepts a new option, `details_only_for_tracked_flags`, which reduces the size of the JSON representation of the flag state by omitting some metadata. Specifically, it omits any data that is normally used for generating detailed evaluation events if a flag does not have event tracking or debugging turned on.

### Fixed:
- JSON data from `all_flags_state` is now slightly smaller even if you do not use the new option described above, because it omits the flag property for event tracking unless that property is true.

## [5.2.0] - 2018-08-29
### Added:
- The new `LDClient` method `variation_detail` allows you to evaluate a feature flag (using the same parameters as you would for `variation`) and receive more information about how the value was calculated. This information is returned in an `EvaluationDetail` object, which contains both the result value and a "reason" object which will tell you, for instance, if the user was individually targeted for the flag or was matched by one of the flag's rules, or if the flag returned the default value due to an error.

### Fixed:
- Evaluating a prerequisite feature flag did not produce an analytics event if the prerequisite flag was off.

 
## [5.1.0] - 2018-08-27
### Added:
- The new `LDClient` method `all_flags_state()` should be used instead of `all_flags()` if you are passing flag data to the front end for use with the JavaScript SDK. It preserves some flag metadata that the front end requires in order to send analytics events correctly. Versions 2.5.0 and above of the JavaScript SDK are able to use this metadata, but the output of `all_flags_state()` will still work with older versions.
- The `all_flags_state()` method also allows you to select only client-side-enabled flags to pass to the front end, by using the option `client_side_only: true`.

### Changed:
- Unexpected exceptions are now logged at `ERROR` level, and exception stacktraces at `DEBUG` level. Previously, both were being logged at `WARN` level.

### Deprecated:
- `LDClient.all_flags()`


## [5.0.1] - 2018-07-02
### Fixed:
Fixed a regression in version 5.0.0 that could prevent the client from reconnecting if the stream connection was dropped by the server.


## [5.0.0] - 2018-06-26
### Changed:
- The client no longer uses Celluloid for streaming I/O. Instead, it uses [socketry](https://github.com/socketry/socketry).
- The client now treats most HTTP 4xx errors as unrecoverable: that is, after receiving such an error, it will not make any more HTTP requests for the lifetime of the client instance, in effect taking the client offline. This is because such errors indicate either a configuration problem (invalid SDK key) or a bug, which is not likely to resolve without a restart or an upgrade. This does not apply if the error is 400, 408, 429, or any 5xx error.
- During initialization, if the client receives any of the unrecoverable errors described above, the client constructor will return immediately; previously it would continue waiting until a timeout. The `initialized?` method will return false in this case.

### Removed:
- The SDK no longer supports Ruby versions below 2.2.6, or JRuby below 9.1.16.

## [4.0.0] - 2018-05-10

### Changed:
- To reduce the network bandwidth used for analytics events, feature request events are now sent as counters rather than individual events, and user details are now sent only at intervals rather than in each event. These behaviors can be modified through the LaunchDarkly UI and with the new configuration option `inline_users_in_events`. For more details, see [Analytics Data Stream Reference](https://docs.launchdarkly.com/v2.0/docs/analytics-data-stream-reference).

### Removed:
- JRuby 1.7 is no longer supported.
- Greatly reduced the number of indirect gem dependencies by removing `moneta`, which was previously a requirement for the Redis feature store.


## [3.0.3] - 2018-03-23
## Fixed
- In the Redis feature store, fixed a synchronization problem that could cause a feature flag update to be missed if several of them happened in rapid succession.

## [3.0.2] - 2018-03-06
## Fixed
- Improved efficiency of logging by not constructing messages that won't be visible at the current log level. (Thanks, [julik](https://github.com/launchdarkly/ruby-client/pull/98)!)


## [3.0.1] - 2018-02-26
### Fixed
- Fixed a bug that could prevent very large feature flags from being updated in streaming mode.


## [3.0.0] - 2018-02-22
### Added
- Support for a new LaunchDarkly feature: reusable user segments.

### Changed
- The feature store interface has been changed to support user segment data as well as feature flags. Existing code that uses `InMemoryFeatureStore` or `RedisFeatureStore` should work as before, but custom feature store implementations will need to be updated.


## [2.5.0] - 2018-02-12

## Added
- Adds support for a future LaunchDarkly feature, coming soon: semantic version user attributes.

## Changed
- It is now possible to compute rollouts based on an integer attribute of a user, not just a string attribute.

## [2.4.1] - 2018-01-23
## Changed
- Reduce logging level for missing flags
- Relax json and faraday dependencies
## Fixed
- Wrap redis bulk updates in a transaction
- Fixed documentation links

## [2.4.0] - 2018-01-12
## Changed
- Will use feature store if already initialized even if connection to service could not be established.  This is useful when flags have been initialized in redis.
- Increase default and  minimum polling interval to 30s
- Strip out unknown top-level attributes

## [2.3.2] - 2017-12-02

### Fixed
- Make sure redis store initializations are atomic


## [2.3.1] - 2017-11-16

### Changed
- Include source code for changes described in 2.3.0


## [2.3.0] - 2017-11-16
## Added
- Add `close` method to Ruby client to stop processing events
- Add support for Redis feature store
- Add support for LDD mode
- Allow user to disable outgoing event stream.

## Changed
- Stop retrying on 401 responses (due to bad sdk keys)

## [2.2.7] - 2017-07-26
## Changed
- Update Readme to fix instructions on installing gem using command line
- Cleaned up formatting on various files (Rubocop)
## [2.2.5] - 2017-05-08
## Changed
- Added proxy support to streaming and http connections. Respects `HTTP_PROXY` and `http_proxy` environment variables as well as the `:proxy => protocol://user:pass@host` configuration parameter.

## [2.1.5] - 2017-03-28
## Changed
- Updated changelog 

## [2.1.1] - 2017-03-28
## Changed
- Bumped nio4r to 2.0

## [2.0.6] - 2017-02-10
## Changed
- Improved handling of http status codes that may not be integers.

## [2.0.5] - 2017-01-31
## Changed
- Improved error handling when connected to flag update stream.

## [2.0.3] - 2016-10-21
## Fixed
- Indirect stream events are now correctly processed

## [2.0.2] - 2016-08-08
## Changed
- The default logger now logs at `info` level

## [2.0.0] - 2016-08-08
### Added
- Support for multivariate feature flags. In addition to booleans, feature flags can now return numbers, strings, dictionaries, or arrays via the `variation` method.
- New `all_flags` method returns all flag values for a specified user.
- If streaming is disabled, the client polls for feature flag changes. If streaming is disabled, the client will default to polling LaunchDarkly every second for updates. The poll interval is configurable via `poll_interval`.
- New `secure_mode_hash` function computes a hash suitable for the new LaunchDarkly JavaScript client's secure mode feature.
- Support for extremely large feature flags. When a large feature flag changes, the stream will include a directive to fetch the updated flag.

### Changed
- You can now initialize the LaunchDarkly client with an optional timeout (specified in seconds). This will block initialization until the client has finished bootstrapping and is able to serve feature flags.
- The streaming implementation (`StreamProcessor`) uses [Celluloid](https://github.com/celluloid/celluloid) under the hood instead of [EventMachine](https://github.com/eventmachine/eventmachine). The dependency on EventMachine has been removed.
- The `store` option has been renamed to `cache_store`.
- Offline mode can no longer be set dynamically. Instead, at configuration time, the `offline` parameter can be set to put the client in offline mode. It is no longer possible to dynamically change whether the client is online and offline (via `set_online` and `set_offline`). Call `offline?` to determine whether or not the client is offline.
- The `debug_stream` configuration option has been removed.
- The `log_timings` configuration option has been removed.

### Deprecated
- The `toggle` call has been deprecated in favor of `variation`.

### Removed
- `update_user_flag_setting` has been removed. To change user settings, use the LaunchDarkly REST API.
