# frozen_string_literal: true

RSpec.describe SolidusShipstation::ShipmentNotice do
  shared_examples "ships or updates the shipment" do
    context "when the order was not shipped yet" do
      # rubocop:disable RSpec/MultipleExpectations
      it "ships the order successfully" do
        shipment_notice = build_shipment_notice(order.shipments.first, shipment_tracking: "1Z1231234")
        shipment_notice.apply

        order.reload
        expect(order.shipments.first).to be_shipped
        expect(order.shipments.first.shipped_at).not_to be_nil
        expect(order.shipments.first.tracking).to eq("1Z1231234")
        expect(order.cartons.first.tracking).to eq("1Z1231234")
      end
      # rubocop:enable RSpec/MultipleExpectations
    end

    context "when the order was already shipped" do
      it "updates the tracking number on the shipment" do
        order.shipments.first.ship!

        shipment_notice = build_shipment_notice(order.shipments.first, shipment_tracking: "1Z1231234")
        shipment_notice.apply

        expect(order.reload.shipments.first.tracking).to eq("1Z1231234")
      end
    end
  end

  context "when capture_at_notification is true" do
    before { stub_configuration(capture_at_notification: true) }

    context "when the order is paid" do
      let(:order) { create_order_ready_to_ship(paid: true) }

      include_examples "ships or updates the shipment"
    end

    context "when the order is not paid" do
      let(:order) { create_order_ready_to_ship(paid: false) }

      context "when the payment can be captured successfully" do
        include_examples "ships or updates the shipment"

        it "pays the order successfully" do
          shipment_notice = build_shipment_notice(order.shipments.first, shipment_tracking: "1Z1231234")
          shipment_notice.apply

          order.reload
          expect(order.payments).to all(be_completed)
          expect(order.reload).to be_paid
        end
      end

      context "when the payment cannot be captured" do
        it "raises a PaymentError" do
          allow_any_instance_of(Spree::Payment).to receive(:capture!).and_raise(Spree::Core::GatewayError)

          shipment_notice = build_shipment_notice(order.shipments.first)

          expect { shipment_notice.apply }.to raise_error(SolidusShipstation::PaymentError) do |e|
            expect(e.cause).to be_instance_of(Spree::Core::GatewayError)
          end
        end
      end
    end
  end

  context "when capture_at_notification is false" do
    before { stub_configuration(capture_at_notification: false) }

    context "when the order is paid" do
      let(:order) { create_order_ready_to_ship(paid: true) }

      include_examples "ships or updates the shipment"
    end

    context "when the order is not paid" do
      it "raises an OrderNotPaidError" do
        stub_configuration(capture_at_notification: false)
        order = create_order_ready_to_ship(paid: false)

        shipment_notice = build_shipment_notice(order.shipments.first)

        expect { shipment_notice.apply }.to raise_error(SolidusShipstation::OrderNotPaidError)
      end
    end
  end

  private

  def create_order_ready_to_ship(paid: true)
    order = create(:order_ready_to_ship)

    unless paid
      order.payments.update_all(state: "pending")
      order.recalculate
    end

    order
  end

  def build_shipment_notice(shipment, shipment_tracking: "1Z1231234")
    SolidusShipstation::ShipmentNotice.new(
      shipment_number: shipment.number,
      shipment_tracking: shipment_tracking
    )
  end
end
