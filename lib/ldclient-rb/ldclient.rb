require "concurrent/atomics"
require "digest/sha1"
require "logger"
require "benchmark"
require "json"
require "openssl"

module LaunchDarkly
  #
  # A client for LaunchDarkly. Client instances are thread-safe. Users
  # should create a single client instance for the lifetime of the application.
  #
  class LDClient
    include Evaluation
    #
    # Creates a new client instance that connects to LaunchDarkly. A custom
    # configuration parameter can also supplied to specify advanced options,
    # but for most use cases, the default configuration is appropriate.
    #
    # @param sdk_key [String] the SDK key for your LaunchDarkly account
    # @param config [Config] an optional client configuration object
    #
    # @return [LDClient] The LaunchDarkly client instance
    def initialize(sdk_key, config = Config.default, wait_for_sec = 5)
      @sdk_key = sdk_key
      @config = config
      @store = config.feature_store

      if @config.offline? || !@config.send_events
        @event_processor = NullEventProcessor.new
      else
        @event_processor = EventProcessor.new(sdk_key, config)
      end

      if @config.use_ldd?
        @config.logger.info { "[LDClient] Started LaunchDarkly Client in LDD mode" }
        return  # requestor and update processor are not used in this mode
      end

      data_source_or_factory = @config.data_source || self.method(:create_default_data_source)
      if data_source_or_factory.respond_to? :call
        @data_source = data_source_or_factory.call(sdk_key, config)
      else
        @data_source = data_source_or_factory
      end

      ready = @data_source.start
      if wait_for_sec > 0
        ok = ready.wait(wait_for_sec)
        if !ok
          @config.logger.error { "[LDClient] Timeout encountered waiting for LaunchDarkly client initialization" }
        elsif !@data_source.initialized?
          @config.logger.error { "[LDClient] LaunchDarkly client initialization failed" }
        end
      end
    end

    #
    # Tells the client that all pending analytics events should be delivered as soon as possible.
    #
    # When the LaunchDarkly client generates analytics events (from {#variation}, {#variation_detail},
    # {#identify}, or {#track}), they are queued on a worker thread. The event thread normally
    # sends all queued events to LaunchDarkly at regular intervals, controlled by the
    # {Config#flush_interval} option. Calling `flush` triggers a send without waiting for the
    # next interval.
    #
    # Flushing is asynchronous, so this method will return before it is complete. However, if you
    # call {#close}, events are guaranteed to be sent before that method returns.
    #
    def flush
      @event_processor.flush
    end

    #
    # @param key [String] the feature flag key
    # @param user [Hash] the user properties
    # @param default [Boolean] (false) the value to use if the flag cannot be evaluated
    # @return [Boolean] the flag value
    # @deprecated Use {#variation} instead.
    #
    def toggle?(key, user, default = false)
      @config.logger.warn { "[LDClient] toggle? is deprecated. Use variation instead" }
      variation(key, user, default)
    end

    #
    # Creates a hash string that can be used by the JavaScript SDK to identify a user.
    # For more information, see ["Secure mode"](https://docs.launchdarkly.com/docs/js-sdk-reference#section-secure-mode).
    #
    # @param user [Hash] the user properties
    # @return [String] a hash string
    #
    def secure_mode_hash(user)
      OpenSSL::HMAC.hexdigest("sha256", @sdk_key, user[:key].to_s)
    end

    # Returns whether the client has been initialized and is ready to serve feature flag requests
    # @return [Boolean] true if the client has been initialized
    def initialized?
      @config.offline? || @config.use_ldd? || @data_source.initialized?
    end

    #
    # Determines the variation of a feature flag to present to a user. At a minimum,
    # the user hash should contain a `:key`.
    #
    # @example Basic user hash
    #      {key: "user@example.com"}
    #
    # For authenticated users, the `:key` should be the unique identifier for
    # your user. For anonymous users, the `:key` should be a session identifier
    # or cookie. In either case, the only requirement is that the key
    # is unique to a user.
    #
    # You can also pass IP addresses and country codes in the user hash.
    #
    # @example More complete user hash
    #   {key: "user@example.com", ip: "127.0.0.1", country: "US"}
    #
    # The user hash can contain arbitrary custom attributes stored in a `:custom` sub-hash:
    #
    # @example A user hash with custom attributes
    #   {key: "user@example.com", custom: {customer_rank: 1000, groups: ["google", "microsoft"]}}
    #
    # Attribute values in the custom hash can be integers, booleans, strings, or
    #   lists of integers, booleans, or strings.
    #
    # @param key [String] the unique feature key for the feature flag, as shown
    #   on the LaunchDarkly dashboard
    # @param user [Hash] a hash containing parameters for the end user requesting the flag
    # @param default the default value of the flag
    #
    # @return the variation to show the user, or the
    #   default value if there's an an error
    def variation(key, user, default)
      evaluate_internal(key, user, default, false).value
    end

    #
    # Determines the variation of a feature flag for a user, like {#variation}, but also
    # provides additional information about how this value was calculated.
    #
    # The return value of `variation_detail` is an {EvaluationDetail} object, which has
    # three properties: the result value, the positional index of this value in the flag's
    # list of variations, and an object describing the main reason why this value was
    # selected. See {EvaluationDetail} for more on these properties.
    #
    # Calling `variation_detail` instead of `variation` also causes the "reason" data to
    # be included in analytics events, if you are capturing detailed event data for this flag.
    #
    # @param key [String] the unique feature key for the feature flag, as shown
    #   on the LaunchDarkly dashboard
    # @param user [Hash] a hash containing parameters for the end user requesting the flag
    # @param default the default value of the flag
    #
    # @return [EvaluationDetail] an object describing the result
    #
    def variation_detail(key, user, default)
      evaluate_internal(key, user, default, true)
    end

    #
    # Registers the user. This method simply creates an analytics event containing the user
    # properties, so that LaunchDarkly will know about that user if it does not already.
    #
    # Calling {#variation} or {#variation_detail} also sends the user information to
    # LaunchDarkly (if events are enabled), so you only need to use {#identify} if you
    # want to identify the user without evaluating a flag.
    #
    # Note that event delivery is asynchronous, so the event may not actually be sent
    # until later; see {#flush}.
    #
    # @param user [Hash] The user to register; this can have all the same user properties
    #   described in {#variation}
    # @return [void]
    #
    def identify(user)
      sanitize_user(user)
      @event_processor.add_event(kind: "identify", key: user[:key], user: user)
    end

    #
    # Tracks that a user performed an event. This method creates a "custom" analytics event
    # containing the specified event name (key), user properties, and optional data.
    #
    # Note that event delivery is asynchronous, so the event may not actually be sent
    # until later; see {#flush}.
    #
    # @param event_name [String] The name of the event
    # @param user [Hash] The user to register; this can have all the same user properties
    #   described in {#variation}
    # @param data [Hash] A hash containing any additional data associated with the event
    # @return [void]
    #
    def track(event_name, user, data)
      sanitize_user(user)
      @event_processor.add_event(kind: "custom", key: event_name, user: user, data: data)
    end

    #
    # Returns all feature flag values for the given user. This method is deprecated - please use
    # {#all_flags_state} instead. Current versions of the client-side SDK will not generate analytics
    # events correctly if you pass the result of `all_flags`.
    #
    # @param user [Hash] The end user requesting the feature flags
    # @return [Hash] a hash of feature flag keys to values
    #
    def all_flags(user)
      all_flags_state(user).values_map
    end

    #
    # Returns a {FeatureFlagsState} object that encapsulates the state of all feature flags for a given user,
    # including the flag values and also metadata that can be used on the front end. This method does not
    # send analytics events back to LaunchDarkly.
    #
    # @param user [Hash] The end user requesting the feature flags
    # @param options [Hash] Optional parameters to control how the state is generated
    # @option options [Boolean] :client_side_only (false) True if only flags marked for use with the
    #   client-side SDK should be included in the state. By default, all flags are included.
    # @option options [Boolean] :with_reasons (false) True if evaluation reasons should be included
    #   in the state (see {#variation_detail}). By default, they are not included.
    # @option options [Boolean] :details_only_for_tracked_flags (false) True if any flag metadata that is
    #   normally only used for event generation - such as flag versions and evaluation reasons - should be
    #   omitted for any flag that does not have event tracking or debugging turned on. This reduces the size
    #   of the JSON data if you are passing the flag state to the front end.
    # @return [FeatureFlagsState] a {FeatureFlagsState} object which can be serialized to JSON
    #
    def all_flags_state(user, options={})
      return FeatureFlagsState.new(false) if @config.offline?

      unless user && !user[:key].nil?
        @config.logger.error { "[LDClient] User and user key must be specified in all_flags_state" }
        return FeatureFlagsState.new(false)
      end

      sanitize_user(user)

      begin
        features = @store.all(FEATURES)
      rescue => exn
        Util.log_exception(@config.logger, "Unable to read flags for all_flags_state", exn)
        return FeatureFlagsState.new(false)
      end

      state = FeatureFlagsState.new(true)
      client_only = options[:client_side_only] || false
      with_reasons = options[:with_reasons] || false
      details_only_if_tracked = options[:details_only_for_tracked_flags] || false
      features.each do |k, f|
        if client_only && !f[:clientSide]
          next
        end
        begin
          result = evaluate(f, user, @store, @config.logger)
          state.add_flag(f, result.detail.value, result.detail.variation_index, with_reasons ? result.detail.reason : nil,
            details_only_if_tracked)
        rescue => exn
          Util.log_exception(@config.logger, "Error evaluating flag \"#{k}\" in all_flags_state", exn)
          state.add_flag(f, nil, nil, with_reasons ? { kind: 'ERROR', errorKind: 'EXCEPTION' } : nil, details_only_if_tracked)
        end
      end

      state
    end

    #
    # Releases all network connections and other resources held by the client, making it no longer usable.
    #
    # @return [void]
    def close
      @config.logger.info { "[LDClient] Closing LaunchDarkly client..." }
      @data_source.stop
      @event_processor.stop
      @store.stop
    end

    private

    def create_default_data_source(sdk_key, config)
      if config.offline?
        return NullUpdateProcessor.new
      end
      requestor = Requestor.new(sdk_key, config)
      if config.stream?
        StreamProcessor.new(sdk_key, config, requestor)
      else
        config.logger.info { "Disabling streaming API" }
        config.logger.warn { "You should only disable the streaming API if instructed to do so by LaunchDarkly support" }
        PollingProcessor.new(config, requestor)
      end
    end

    # @return [EvaluationDetail]
    def evaluate_internal(key, user, default, include_reasons_in_events)
      if @config.offline?
        return error_result('CLIENT_NOT_READY', default)
      end

      if !initialized?
        if @store.initialized?
          @config.logger.warn { "[LDClient] Client has not finished initializing; using last known values from feature store" }
        else
          @config.logger.error { "[LDClient] Client has not finished initializing; feature store unavailable, returning default value" }
          @event_processor.add_event(kind: "feature", key: key, value: default, default: default, user: user)
          return error_result('CLIENT_NOT_READY', default)
        end
      end

      sanitize_user(user) if !user.nil?
      feature = @store.get(FEATURES, key)

      if feature.nil?
        @config.logger.info { "[LDClient] Unknown feature flag \"#{key}\". Returning default value" }
        detail = error_result('FLAG_NOT_FOUND', default)
        @event_processor.add_event(kind: "feature", key: key, value: default, default: default, user: user,
          reason: include_reasons_in_events ? detail.reason : nil)
        return detail
      end

      unless user
        @config.logger.error { "[LDClient] Must specify user" }
        detail = error_result('USER_NOT_SPECIFIED', default)
        @event_processor.add_event(make_feature_event(feature, user, detail, default, include_reasons_in_events))
        return detail
      end

      begin
        res = evaluate(feature, user, @store, @config.logger)
        if !res.events.nil?
          res.events.each do |event|
            @event_processor.add_event(event)
          end
        end
        detail = res.detail
        if detail.default_value?
          detail = EvaluationDetail.new(default, nil, detail.reason)
        end
        @event_processor.add_event(make_feature_event(feature, user, detail, default, include_reasons_in_events))
        return detail
      rescue => exn
        Util.log_exception(@config.logger, "Error evaluating feature flag \"#{key}\"", exn)
        detail = error_result('EXCEPTION', default)
        @event_processor.add_event(make_feature_event(feature, user, detail, default, include_reasons_in_events))
        return detail
      end
    end

    def sanitize_user(user)
      if user[:key]
        user[:key] = user[:key].to_s
      end
    end

    def make_feature_event(flag, user, detail, default, with_reasons)
      {
        kind: "feature",
        key: flag[:key],
        user: user,
        variation: detail.variation_index,
        value: detail.value,
        default: default,
        version: flag[:version],
        trackEvents: flag[:trackEvents],
        debugEventsUntilDate: flag[:debugEventsUntilDate],
        reason: with_reasons ? detail.reason : nil
      }
    end
  end

  #
  # Used internally when the client is offline.
  # @private
  #
  class NullUpdateProcessor
    def start
      e = Concurrent::Event.new
      e.set
      e
    end

    def initialized?
      true
    end

    def stop
    end
  end
end
