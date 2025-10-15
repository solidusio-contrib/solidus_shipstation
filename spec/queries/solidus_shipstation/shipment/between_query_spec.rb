RSpec.describe SolidusShipstation::Shipment::BetweenQuery do
  describe ".apply" do
    it "returns shipments whose updated_at falls within the given time range" do
      shipment = create(:shipment) { |s| s.update_column(:updated_at, Time.zone.now) }

      result = described_class.apply(
        Spree::Shipment.all,
        from: Time.zone.yesterday,
        to: Time.zone.tomorrow
      )

      expect(result).to eq([shipment])
    end

    it "returns shipments whose order's updated_at falls within the given time range" do
      order = create(:order) { |o| o.update_column(:updated_at, Time.zone.now) }
      shipment = create(:shipment, order: order)

      result = described_class.apply(
        Spree::Shipment.all,
        from: Time.zone.yesterday,
        to: Time.zone.tomorrow
      )

      expect(result).to eq([shipment])
    end

    it "does not return shipments whose updated_at does not fall within the given time range" do
      create(:shipment) { |s| s.update_column(:updated_at, Time.zone.now) }

      result = described_class.apply(
        Spree::Shipment.all,
        from: Time.zone.tomorrow,
        to: Time.zone.tomorrow + 1.day
      )

      expect(result).to eq([])
    end

    it "does not return shipments whose order's updated_at falls within the given time range" do
      order = create(:order) { |o| o.update_column(:updated_at, Time.zone.now) }
      create(:shipment, order: order)

      result = described_class.apply(
        Spree::Shipment.all,
        from: Time.zone.tomorrow,
        to: Time.zone.tomorrow + 1.day
      )

      expect(result).to eq([])
    end
  end
end
