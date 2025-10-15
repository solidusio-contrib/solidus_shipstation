RSpec.describe SolidusShipstation::Api::ShipmentSerializer do
  describe "#call" do
    it "serializes the shipment" do
      shipment = create(:order_ready_to_ship).shipments.first

      serializer = described_class.new(store_id: "12345678")
      result = serializer.call(shipment)

      expect(result).to be_instance_of(Hash)
    end

    it "sets residential = false in address if company is given" do
      order = create(:order_ready_to_ship,
        bill_address: build(:address, company: "ACME Co."),
        ship_address: build(:address, company: nil))
      shipment = order.shipments.first

      serializer = described_class.new(store_id: "12345678")
      result = serializer.call(shipment)

      expect(result[:billTo][:residential]).to be false
      expect(result[:shipTo][:residential]).to be true
    end
  end
end
