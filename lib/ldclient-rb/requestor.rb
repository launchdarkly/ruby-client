require "concurrent/atomics"
require "json"
require "net/http/persistent"

module LaunchDarkly
  # @private
  class UnexpectedResponseError < StandardError
    def initialize(status)
      @status = status
      super("HTTP error #{status}")
    end

    def status
      @status
    end
  end

  # @private
  class Requestor
    CacheEntry = Struct.new(:etag, :body)

    def initialize(sdk_key, config)
      @sdk_key = sdk_key
      @config = config
      @client = Net::HTTP::Persistent.new
      @client.open_timeout = @config.connect_timeout
      @client.read_timeout = @config.read_timeout
      @cache = @config.cache_store
    end

    def request_flag(key)
      make_request("/sdk/latest-flags/" + key)
    end

    def request_segment(key)
      make_request("/sdk/latest-segments/" + key)
    end

    def request_all_data()
      make_request("/sdk/latest-all")
    end
    
    def stop
      @client.shutdown
    end

    private

    def make_request(path)
      uri = URI(@config.base_uri + path)
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = @sdk_key
      req["User-Agent"] = "RubyClient/" + LaunchDarkly::VERSION
      cached = @cache.read(uri)
      if !cached.nil?
        req["If-None-Match"] = cached.etag
      end
      res = @client.request(uri, req)
      status = res.code.to_i
      @config.logger.debug { "[LDClient] Got response from uri: #{uri}\n\tstatus code: #{status}\n\theaders: #{res.to_hash}\n\tbody: #{res.body}" }

      if status == 304 && !cached.nil?
        body = cached.body
      else
        @cache.delete(uri)
        if status < 200 || status >= 300
          raise UnexpectedResponseError.new(status)
        end
        body = fix_encoding(res.body, res["content-type"])
        etag = res["etag"]
        @cache.write(uri, CacheEntry.new(etag, body)) if !etag.nil?
      end
      JSON.parse(body, symbolize_names: true)
    end

    def fix_encoding(body, content_type)
      return body if content_type.nil?
      media_type, charset = parse_content_type(content_type)
      return body if charset.nil?
      body.force_encoding(Encoding::find(charset)).encode(Encoding::UTF_8)
    end

    def parse_content_type(value)
      return [nil, nil] if value.nil? || value == ''
      parts = value.split(/; */)
      return [value, nil] if parts.count < 2
      charset = nil
      parts.each do |part|
        fields = part.split('=')
        if fields.count >= 2 && fields[0] == 'charset'
          charset = fields[1]
          break
        end
      end
      return [parts[0], charset]
    end
  end
end
