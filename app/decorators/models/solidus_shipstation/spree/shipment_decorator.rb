# frozen_string_literal: true

module SolidusShipstation
  module Spree
    module ShipmentDecorator
      def self.prepended(base)
        base.singleton_class.prepend ClassMethods
      end

      module ClassMethods
        def exportable
          ::Spree.deprecator.warn <<~DEPRECATION
            `Spree::Shipment.exportable` is deprecated and will be removed in a future version
            of solidus_shipstation. Please use `SolidusShipstation::Shipment::ExportableQuery.apply`.
          DEPRECATION

          SolidusShipstation::Shipment::ExportableQuery.apply(self)
        end

        def between(from, to)
          ::Spree.deprecator.warn <<~DEPRECATION
            `Spree::Shipment.between` is deprecated and will be removed in a future version
            of solidus_shipstation. Please use `SolidusShipstation::Shipment::BetweenQuery.apply`.
          DEPRECATION

          SolidusShipstation::Shipment::BetweenQuery.apply(self, from: from, to: to)
        end
      end

      ::Spree::Shipment.prepend self
    end
  end
end
