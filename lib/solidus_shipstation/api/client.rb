# frozen_string_literal: true

module SolidusShipstation
  module Api
    class Client
      class << self
        def from_config
          new(
            request_runner: RequestRunner.from_config,
            error_handler: SolidusShipstation.config.error_handler,
            shipment_serializer: SolidusShipstation.config.api_shipment_serializer,
          )
        end
      end

      attr_reader :request_runner, :error_handler, :shipment_serializer

      def initialize(request_runner:, error_handler:, shipment_serializer:)
        @request_runner = request_runner
        @error_handler = error_handler
        @shipment_serializer = shipment_serializer
      end

      def bulk_create_orders(shipments)
        params = shipments.map do |shipment|
          shipment_serializer.call(shipment)
        rescue StandardError => e
          error_handler.call(e, shipment: shipment)
          nil
        end.compact

        return if params.empty?

        request_runner.call(:post, '/orders/createorders', params)
      end

      def create_order(shipment)
        begin
          params = shipment_serializer.call(shipment)
        rescue StandardError => e
          error_handler.call(e, shipment: shipment)
          return
        end

        request_runner.call(:post, '/orders/createorder', params)
      end
    end
  end
end
