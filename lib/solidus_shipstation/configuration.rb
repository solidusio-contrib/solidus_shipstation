# frozen_string_literal: true

module SolidusShipstation
  class Configuration
    attr_accessor(
      :username,
      :password,
      :weight_units,
      :ssl_encrypted,
      :capture_at_notification,
      :export_canceled_shipments,
      :api_batch_size,
      :api_sync_threshold,
      :api_shipment_serializer,
      :api_key,
      :api_secret,
      :api_shipment_matcher,
      :api_request_attempts,
      :error_handler,
      :shipment_notice_class
    )

    def initialize
      @api_batch_size = 100
      @api_sync_threshold = 7.days
      @api_request_attempts = 1
      @error_handler = ->(error, extra = {}) {
        Rails.logger.error "#{error.inspect} (#{extra.inspect})"
      }
      @api_shipment_matcher = proc do |shipstation_order, shipments|
        shipments.find { |shipment| shipment.number == shipstation_order['orderNumber'] }
      end

      @shipment_notice_class = 'SolidusShipstation::ShipmentNotice'
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    alias config configuration

    def configure
      yield configuration
    end
  end
end
