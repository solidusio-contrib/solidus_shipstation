RSpec.describe SolidusShipstation::Shipment::ExportableQuery do
  describe ".apply" do
    context "when capture_at_notification is false and export_canceled_shipments is false" do
      it "returns ready shipments from complete orders" do
        stub_configuration(capture_at_notification: false, export_canceled_shipments: false)

        ready_shipment = create(:order_ready_to_ship).shipments.first
        create(:order_ready_to_ship) { |o| o.shipments.first.cancel! }
        create(:shipped_order)

        expect(described_class.apply(Spree::Shipment.all)).to eq([ready_shipment])
      end
    end

    context "when capture_at_notification is true and export_canceled_shipments is false" do
      it "returns non-canceled shipments from complete orders" do
        stub_configuration(capture_at_notification: true, export_canceled_shipments: false)

        ready_shipment = create(:order_ready_to_ship).shipments.first
        shipped_shipment = create(:shipped_order).shipments.first
        create(:order_ready_to_ship) { |o| o.shipments.first.cancel! }

        expect(described_class.apply(Spree::Shipment.all)).to eq([ready_shipment, shipped_shipment])
      end
    end

    context "when capture_at_notification is false and export_canceled_shipments is true" do
      it "returns ready and canceled shipments from complete orders" do
        stub_configuration(capture_at_notification: false, export_canceled_shipments: true)

        ready_shipment = create(:order_ready_to_ship).shipments.first
        canceled_shipment = create(:order_ready_to_ship).shipments.first
        canceled_shipment.cancel!
        create(:shipped_order)

        expect(described_class.apply(Spree::Shipment.all)).to eq([ready_shipment, canceled_shipment])
      end
    end

    context "when capture_at_notification is true and export_canceled_shipments is true" do
      it "returns all shipments from complete orders" do
        stub_configuration(capture_at_notification: true, export_canceled_shipments: true)

        ready_shipment = create(:order_ready_to_ship).shipments.first
        canceled_shipment = create(:order_ready_to_ship).shipments.first
        canceled_shipment.cancel!
        shipped_shipment = create(:shipped_order).shipments.first

        expect(described_class.apply(Spree::Shipment.all)).to eq([ready_shipment, canceled_shipment, shipped_shipment])
      end
    end
  end
end
