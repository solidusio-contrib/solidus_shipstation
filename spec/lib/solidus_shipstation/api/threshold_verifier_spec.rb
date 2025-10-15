RSpec.describe SolidusShipstation::Api::ThresholdVerifier do
  context "when the shipment's order was completed" do
    context "when the shipment was never synced with ShipStation yet" do
      it "returns true when the shipment was never synced with ShipStation yet" do
        stub_configuration(api_sync_threshold: 10.minutes)
        shipment = create(:order_ready_to_ship).shipments.first

        expect(described_class.call(shipment)).to eq(true)
      end

      it "returns false when the shipment's order was created too far in the past" do
        stub_configuration(api_sync_threshold: 10.minutes)
        shipment = create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 11.minutes.ago)
        end

        expect(described_class.call(shipment)).to eq(false)
      end
    end

    context "when the shipment was already synced with ShipStation" do
      it "returns true when the shipment is pending a ShipStation re-sync" do
        stub_configuration(api_sync_threshold: 10.minutes)
        shipment = create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 4.minutes.ago)
          s.update_columns(shipstation_synced_at: 5.minutes.ago)
        end

        expect(described_class.call(shipment)).to eq(true)
      end

      it "returns false when the shipment is up-to-date in ShipStation" do
        stub_configuration(api_sync_threshold: 10.minutes)
        shipment = create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 6.minutes.ago)
          s.update_columns(shipstation_synced_at: 5.minutes.ago)
        end

        expect(described_class.call(shipment)).to eq(false)
      end

      it "returns false when the order was updated too far in the past" do
        stub_configuration(api_sync_threshold: 10.minutes)
        shipment = create(:order_ready_to_ship).shipments.first.tap do |s|
          s.order.update_columns(updated_at: 11.minutes.ago)
          s.update_columns(shipstation_synced_at: 12.minutes.ago)
        end

        expect(described_class.call(shipment)).to eq(false)
      end
    end
  end

  context "when the shipment's order was not completed" do
    it "returns false" do
      shipment = create(:shipment)

      expect(described_class.call(shipment)).to eq(false)
    end
  end
end
