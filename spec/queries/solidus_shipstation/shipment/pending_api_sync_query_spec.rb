RSpec.describe SolidusShipstation::Shipment::PendingApiSyncQuery do
  describe ".apply" do
    context "when dealing with shipments that were never synced" do
      it "returns the shipments that are within the threshold" do
        stub_configuration(api_sync_threshold: 10.minutes)
        shipment = create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 9.minutes.ago)
        end
        create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 11.minutes.ago)
        end

        expect(described_class.apply(Spree::Shipment.all)).to match_array([shipment])
      end
    end

    context "when dealing with shipments that were already synced" do
      it "returns the shipments that are within the threshold and pending a re-sync" do
        stub_configuration(api_sync_threshold: 10.minutes)
        shipment = create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 7.minutes.ago)
          s.update_columns(shipstation_synced_at: 8.minutes.ago)
        end
        create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 9.minutes.ago)
          s.update_columns(shipstation_synced_at: 8.minutes.ago)
        end
        create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 11.minutes.ago)
          s.update_columns(shipstation_synced_at: 10.minutes.ago)
        end

        expect(described_class.apply(Spree::Shipment.all)).to match_array([shipment])
      end
    end
  end
end
