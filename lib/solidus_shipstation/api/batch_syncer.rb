# frozen_string_literal: true

module SolidusShipstation
  module Api
    class BatchSyncer
      class << self
        def from_config
          new(
            client: SolidusShipstation::Api::Client.from_config,
            shipment_matcher: SolidusShipstation.config.api_shipment_matcher,
          )
        end
      end

      attr_reader :client, :shipment_matcher

      def initialize(client:, shipment_matcher:)
        @client = client
        @shipment_matcher = shipment_matcher
      end

      def call(shipments)
        begin
          response = client.bulk_create_orders(shipments)
        rescue RateLimitedError => e
          ::Spree::Bus.publish(:'solidus_shipstation.api.rate_limited',
            shipments: shipments,
            error: e
          )

          raise e
        rescue RequestError => _e
          sync_batch_shipments_sequentially(shipments)
          return
        end

        return unless response

        response['results'].each do |shipstation_order|
          post_sync(shipstation_order, shipments)
        end
      end

      UNMODIFIABLE_RX = /The order with orderKey "\w+" is inactive and cannot be modified/.freeze

      def sync_batch_shipments_sequentially(shipments)
        shipstation_synced_shipments = []
        failed_shipments = []
        error_messages = []

        shipments.each do |shipment|
          next if shipment.unsyncable?

          begin
            shipstation_order = create_order(shipment)
            next unless shipstation_order

            shipstation_synced_shipments << shipment
          rescue RateLimitedError => e
            ::Spree::Bus.publish(:'solidus_shipstation.api.rate_limited',
                                 shipments: shipments - shipstation_synced_shipments,
                                 error: e
            )
            raise e
          rescue RequestError => e
            failed_shipments << shipment
            mark_shipment_unsyncable(shipment, e)
            error_messages << e.message
            next
          end
        end

        if failed_shipments.any?
          error_message = error_messages.join('.')
          ::Spree::Bus.publish(:'solidus_shipstation.api.sync_errored',
            shipments: failed_shipments,
            error: error_message
          )

          raise StandardError.new(error_message)
        end
      end

      def post_sync(shipstation_order, shipments)
        shipment = shipment_matcher.call(shipstation_order, shipments)

        if failed?(shipstation_order, shipment)
          mark_shipment_unsyncable(shipment, shipstation_order.fetch('errorMessage'))
          return false
        end

        sync_opts = {
          shipstation_synced_at: Time.zone.now,
          shipstation_order_id: shipstation_order['orderId']
        }

        shipstation_store_id = shipstation_order.dig('advancedOptions', 'storeId')
        sync_opts[:shipstation_store_id] = shipstation_store_id if shipstation_store_id

        shipment.update_columns(sync_opts)

        ::Spree::Bus.publish(:'solidus_shipstation.api.sync_completed',
          shipment: shipment,
          payload: shipstation_order)

        true
      end

      def failed?(shipstation_order, shipment)
        unmodifiable = (shipstation_order.fetch('errorMessage') || '').match?(UNMODIFIABLE_RX)

        return false unless !shipstation_order['success'] && !unmodifiable

        ::Spree::Bus.publish(:'solidus_shipstation.api.sync_failed',
          shipment: shipment,
          payload: shipstation_order)
      end

      def mark_shipment_unsyncable(shipment, message)
        shipment.send_failed_shipstation_sync_slack_alert(message)
        shipment.touch(:unsyncable)
      end
    end
  end
end
