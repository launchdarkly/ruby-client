require "logger"

module LaunchDarkly
  #
  # This class exposes advanced configuration options for the LaunchDarkly
  # client library. Most users will not need to use a custom configuration--
  # the default configuration sets sane defaults for most use cases.
  #
  #
  class Config
    #
    # Constructor for creating custom LaunchDarkly configurations.
    #
    # @param opts [Hash] the configuration options
    # @option opts [Logger] :logger A logger to use for messages from the
    #   LaunchDarkly client. Defaults to the Rails logger in a Rails
    #   environment, or stdout otherwise.
    # @option opts [String] :base_uri ("https://app.launchdarkly.com") The base
    #   URL for the LaunchDarkly server. Most users should use the default value.
    # @option opts [String] :stream_uri ("https://stream.launchdarkly.com") The
    #   URL for the LaunchDarkly streaming events server. Most users should use the default value.
    # @option opts [String] :events_uri ("https://events.launchdarkly.com") The
    #   URL for the LaunchDarkly events server. Most users should use the default value.
    # @option opts [Integer] :capacity (10000) The capacity of the events
    #   buffer. The client buffers up to this many events in memory before
    #   flushing. If the capacity is exceeded before the buffer is flushed,
    #   events will be discarded.
    # @option opts [Float] :flush_interval (30) The number of seconds between
    #   flushes of the event buffer.
    # @option opts [Float] :read_timeout (10) The read timeout for network
    #   connections in seconds.
    # @option opts [Float] :connect_timeout (2) The connect timeout for network
    #   connections in seconds.
    # @option opts [Object] :cache_store A cache store for the Faraday HTTP caching
    #   library. Defaults to the Rails cache in a Rails environment, or a
    #   thread-safe in-memory store otherwise.
    # @option opts [Object] :feature_store A store for feature flags and related data. Defaults to an in-memory
    #   cache, or you can use RedisFeatureStore.
    # @option opts [Boolean] :use_ldd (false) Whether you are using the LaunchDarkly relay proxy in
    #   daemon mode. In this configuration, the client will not use a streaming connection to listen
    #   for updates, but instead will get feature state from a Redis instance. The `stream` and
    #   `poll_interval` options will be ignored if this option is set to true.
    # @option opts [Boolean] :offline (false) Whether the client should be initialized in 
    #   offline mode. In offline mode, default values are returned for all flags and no 
    #   remote network requests are made.
    # @option opts [Float] :poll_interval (30) The number of seconds between polls for flag updates
    #   if streaming is off.
    # @option opts [Boolean] :stream (true) Whether or not the streaming API should be used to receive flag updates.
    #   Streaming should only be disabled on the advice of LaunchDarkly support.
    # @option opts [Boolean] all_attributes_private (false) If true, all user attributes (other than the key)
    #   will be private, not just the attributes specified in `private_attribute_names`.
    # @option opts [Array] :private_attribute_names  Marks a set of attribute names private. Any users sent to
    #  LaunchDarkly with this configuration active will have attributes with these names removed.
    # @option opts [Boolean] :send_events (true) Whether or not to send events back to LaunchDarkly.
    #   This differs from `offline` in that it affects only the sending of client-side events, not
    #   streaming or polling for events from the server.
    # @option opts [Integer] :user_keys_capacity (1000) The number of user keys that the event processor
    #   can remember at any one time, so that duplicate user details will not be sent in analytics events.
    # @option opts [Float] :user_keys_flush_interval (300) The interval in seconds at which the event
    #   processor will reset its set of known user keys.
    # @option opts [Boolean] :inline_users_in_events (false) Whether to include full user details in every
    #   analytics event. By default, events will only include the user key, except for one "index" event
    #   that provides the full details for the user.
    # @option opts [Object] :update_processor An object that will receive feature flag data from LaunchDarkly.
    #   Defaults to either the streaming or the polling processor, can be customized for tests.
    # @return [type] [description]
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
    def initialize(opts = {})
      @base_uri = (opts[:base_uri] || Config.default_base_uri).chomp("/")
      @stream_uri = (opts[:stream_uri] || Config.default_stream_uri).chomp("/")
      @events_uri = (opts[:events_uri] || Config.default_events_uri).chomp("/")
      @capacity = opts[:capacity] || Config.default_capacity
      @logger = opts[:logger] || Config.default_logger
      @cache_store = opts[:cache_store] || Config.default_cache_store
      @flush_interval = opts[:flush_interval] || Config.default_flush_interval
      @connect_timeout = opts[:connect_timeout] || Config.default_connect_timeout
      @read_timeout = opts[:read_timeout] || Config.default_read_timeout
      @feature_store = opts[:feature_store] || Config.default_feature_store
      @stream = opts.has_key?(:stream) ? opts[:stream] : Config.default_stream
      @use_ldd = opts.has_key?(:use_ldd) ? opts[:use_ldd] : Config.default_use_ldd
      @offline = opts.has_key?(:offline) ? opts[:offline] : Config.default_offline
      @poll_interval = opts.has_key?(:poll_interval) && opts[:poll_interval] > Config.default_poll_interval ? opts[:poll_interval] : Config.default_poll_interval
      @proxy = opts[:proxy] || Config.default_proxy
      @all_attributes_private = opts[:all_attributes_private] || false
      @private_attribute_names = opts[:private_attribute_names] || []
      @send_events = opts.has_key?(:send_events) ? opts[:send_events] : Config.default_send_events
      @user_keys_capacity = opts[:user_keys_capacity] || Config.default_user_keys_capacity
      @user_keys_flush_interval = opts[:user_keys_flush_interval] || Config.default_user_keys_flush_interval
      @inline_users_in_events = opts[:inline_users_in_events] || false
      @update_processor = opts[:update_processor]
    end

    #
    # The base URL for the LaunchDarkly server.
    #
    # @return [String] The configured base URL for the LaunchDarkly server.
    attr_reader :base_uri

    #
    # The base URL for the LaunchDarkly streaming server.
    #
    # @return [String] The configured base URL for the LaunchDarkly streaming server.
    attr_reader :stream_uri

    #
    # The base URL for the LaunchDarkly events server.
    #
    # @return [String] The configured base URL for the LaunchDarkly events server.
    attr_reader :events_uri

    #
    # Whether streaming mode should be enabled. Streaming mode asynchronously updates
    # feature flags in real-time using server-sent events.
    #
    # @return [Boolean] True if streaming mode should be enabled
    def stream?
      @stream
    end

    #
    # Whether to use the LaunchDarkly relay proxy in daemon mode. In this mode, we do
    # not use polling or streaming to get feature flag updates from the server, but instead
    # read them from a Redis instance that is updated by the proxy.
    #
    # @return [Boolean] True if using the LaunchDarkly relay proxy in daemon mode
    def use_ldd?
      @use_ldd
    end
    
    # TODO docs
    def offline?
      @offline
    end

    #
    # The number of seconds between flushes of the event buffer. Decreasing the flush interval means
    # that the event buffer is less likely to reach capacity.
    #
    # @return [Float] The configured number of seconds between flushes of the event buffer.
    attr_reader :flush_interval

    #
    # The number of seconds to wait before polling for feature flag updates. This option has no
    # effect unless streaming is disabled
    attr_reader :poll_interval

    #
    # The configured logger for the LaunchDarkly client. The client library uses the log to
    # print warning and error messages.
    #
    # @return [Logger] The configured logger
    attr_reader :logger

    #
    # The capacity of the events buffer. The client buffers up to this many
    # events in memory before flushing. If the capacity is exceeded before
    # the buffer is flushed, events will be discarded.
    # Increasing the capacity means that events are less likely to be discarded,
    # at the cost of consuming more memory.
    #
    # @return [Integer] The configured capacity of the event buffer
    attr_reader :capacity

    #
    # The store for the Faraday HTTP caching library. Stores should respond to
    # 'read' and 'write' requests.
    #
    # @return [Object] The configured store for the Faraday HTTP caching library.
    attr_reader :cache_store

    #
    # The read timeout for network connections in seconds.
    #
    # @return [Float] The read timeout in seconds.
    attr_reader :read_timeout

    #
    # The connect timeout for network connections in seconds.
    #
    # @return [Float] The connect timeout in seconds.
    attr_reader :connect_timeout

    #
    # A store for feature flag configuration rules.
    #
    attr_reader :feature_store

    # The proxy configuration string
    #
    attr_reader :proxy

    attr_reader :all_attributes_private

    attr_reader :private_attribute_names
    
    #
    # Whether to send events back to LaunchDarkly.
    #
    attr_reader :send_events

    #
    # The number of user keys that the event processor can remember at any one time, so that
    # duplicate user details will not be sent in analytics events.
    #
    attr_reader :user_keys_capacity

    #
    # The interval in seconds at which the event processor will reset its set of known user keys.
    #
    attr_reader :user_keys_flush_interval

    #
    # Whether to include full user details in every
    # analytics event. By default, events will only include the user key, except for one "index" event
    # that provides the full details for the user.
    #
    attr_reader :inline_users_in_events

    attr_reader :update_processor
    
    #
    # The default LaunchDarkly client configuration. This configuration sets
    # reasonable defaults for most users.
    #
    # @return [Config] The default LaunchDarkly configuration.
    def self.default
      Config.new
    end

    def self.default_capacity
      10000
    end

    def self.default_base_uri
      "https://app.launchdarkly.com"
    end

    def self.default_stream_uri
      "https://stream.launchdarkly.com"
    end

    def self.default_events_uri
      "https://events.launchdarkly.com"
    end

    def self.default_cache_store
      defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : ThreadSafeMemoryStore.new
    end

    def self.default_flush_interval
      10
    end

    def self.default_read_timeout
      10
    end

    def self.default_connect_timeout
      2
    end

    def self.default_proxy
      nil
    end

    def self.default_logger
      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger 
      else 
        log = ::Logger.new($stdout)
        log.level = ::Logger::WARN
        log
      end
    end

    def self.default_stream
      true
    end

    def self.default_use_ldd
      false
    end

    def self.default_feature_store
      InMemoryFeatureStore.new
    end

    def self.default_offline
      false
    end

    def self.default_poll_interval
      30
    end

    def self.default_send_events
      true
    end

    def self.default_user_keys_capacity
      1000
    end

    def self.default_user_keys_flush_interval
      300
    end
  end
end
