require "json"

module LaunchDarkly
  module Impl
    module Integrations
      module Consul
        #
        # Internal implementation of the Consul feature store, intended to be used with CachingStoreWrapper.
        #
        class ConsulFeatureStoreCore
          begin
            require "diplomat"
            CONSUL_ENABLED = true
          rescue ScriptError, StandardError
            CONSUL_ENABLED = false
          end

          def initialize(opts)
            if !CONSUL_ENABLED
              raise RuntimeError.new("can't use Consul feature store without the 'diplomat' gem")
            end

            @prefix = (opts[:prefix] || LaunchDarkly::Integrations::Consul.default_prefix) + '/'
            @logger = opts[:logger] || Config.default_logger
            Diplomat.configuration = opts[:consul_config] if !opts[:consul_config].nil?
            @logger.info("ConsulFeatureStore: using Consul host at #{Diplomat.configuration.url}")
          end

          def init_internal(all_data)
            # Start by reading the existing keys; we will later delete any of these that weren't in all_data.
            unused_old_keys = Set.new
            keys = Diplomat::Kv.get(@prefix, { keys: true, recurse: true }, :return)
            unused_old_keys.merge(keys) if keys != ""

            ops = []
            num_items = 0

            # Insert or update every provided item
            all_data.each do |kind, items|
              items.values.each do |item|
                value = item.to_json
                key = item_key(kind, item[:key])
                ops.push({ 'KV' => { 'Verb' => 'set', 'Key' => key, 'Value' => value } })
                unused_old_keys.delete(key)
                num_items = num_items + 1
              end
            end

            # Now delete any previously existing items whose keys were not in the current data
            unused_old_keys.each do |key|
              ops.push({ 'KV' => { 'Verb' => 'delete', 'Key' => key } })
            end
    
            # Now set the special key that we check in initialized_internal?
            ops.push({ 'KV' => { 'Verb' => 'set', 'Key' => inited_key, 'Value' => '' } })
            
            ConsulUtil.batch_operations(ops)

            @logger.info { "Initialized database with #{num_items} items" }
          end

          def get_internal(kind, key)
            value = Diplomat::Kv.get(item_key(kind, key), {}, :return)  # :return means "don't throw an error if not found"
            (value.nil? || value == "") ? nil : JSON.parse(value, symbolize_names: true)
          end

          def get_all_internal(kind)
            items_out = {}
            results = Diplomat::Kv.get(kind_key(kind), { recurse: true }, :return)
            (results == "" ? [] : results).each do |result|
              value = result[:value]
              if !value.nil?
                item = JSON.parse(value, symbolize_names: true)
                items_out[item[:key].to_sym] = item
              end
            end
            items_out
          end

          def upsert_internal(kind, new_item)
            key = item_key(kind, new_item[:key])
            json = new_item.to_json

            # We will potentially keep retrying indefinitely until someone's write succeeds
            while true
              old_value = Diplomat::Kv.get(key, { decode_values: true }, :return)
              if old_value.nil? || old_value == ""
                mod_index = 0
              else
                puts("old_value = #{old_value}")
                old_item = JSON.parse(old_value[0]["Value"], symbolize_names: true)
                # Check whether the item is stale. If so, don't do the update (and return the existing item to
                # FeatureStoreWrapper so it can be cached)
                if old_item[:version] >= new_item[:version]
                  return old_item
                end
                mod_index = old_value[0]["ModifyIndex"]
              end

              # Otherwise, try to write. We will do a compare-and-set operation, so the write will only succeed if
              # the key's ModifyIndex is still equal to the previous value. If the previous ModifyIndex was zero,
              # it means the key did not previously exist and the write will only succeed if it still doesn't exist.
              success = Diplomat::Kv.put(key, json, cas: mod_index)
              return new_item if success

              # If we failed, retry the whole shebang
              @logger.debug { "Concurrent modification detected, retrying" }
            end
          end

          def initialized_internal?
            value = Diplomat::Kv.get(inited_key, {}, :return)
            !value.nil? && value != ""
          end

          def stop
            # There's no Consul client instance to dispose of
          end

          private

          def item_key(kind, key)
            kind_key(kind) + key.to_s
          end

          def kind_key(kind)
            @prefix + kind[:namespace] + '/'
          end
          
          def inited_key
            @prefix + '$inited'
          end
        end

        class ConsulUtil
          #
          # Submits as many transactions as necessary to submit all of the given operations.
          # The ops array is consumed.
          #
          def self.batch_operations(ops)
            batch_size = 64  # Consul can only do this many at a time
            while true
              chunk = ops.shift(batch_size)
              break if chunk.empty?
              Diplomat::Kv.txn(chunk)
            end
          end
        end
      end
    end
  end
end
