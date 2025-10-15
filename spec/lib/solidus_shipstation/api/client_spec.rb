RSpec.describe SolidusShipstation::Api::Client do
  describe ".from_config" do
    it "generates a client from the configuration" do
      request_runner = instance_double("SolidusShipstation::Api::RequestRunner")
      error_handler = instance_spy("Proc")
      shipment_serializer = instance_spy("SolidusShipstation::Api::Serializer")
      allow(SolidusShipstation::Api::RequestRunner).to receive(:from_config).and_return(request_runner)
      allow(SolidusShipstation.config).to receive_messages(
        error_handler: error_handler,
        api_shipment_serializer: shipment_serializer
      )

      client = described_class.from_config

      expect(client).to have_attributes(
        request_runner: request_runner,
        error_handler: error_handler,
        shipment_serializer: shipment_serializer
      )
    end
  end

  describe "#bulk_create_orders" do
    it "calls the bulk order creation endpoint" do
      request_runner = instance_spy("SolidusShipstation::Api::RequestRunner")
      shipment = build_stubbed(:shipment)
      serialized_shipment = {"key" => "value"}

      client = build_client(
        request_runner: request_runner,
        shipment_serializer: stub_shipment_serializer(shipment => serialized_shipment)
      )
      client.bulk_create_orders([shipment])

      expect(request_runner).to have_received(:call).with(
        :post,
        "/orders/createorders",
        [serialized_shipment]
      )
    end

    it "does not fail for serialization errors" do
      request_runner = instance_spy("SolidusShipstation::Api::RequestRunner")
      successful_shipment = build_stubbed(:shipment)
      serialized_shipment = {"key" => "value"}
      failing_shipment = build_stubbed(:shipment)
      error = RuntimeError.new("Failed to serialize shipment!")

      client = build_client(
        request_runner: request_runner,
        shipment_serializer: stub_shipment_serializer(
          successful_shipment => serialized_shipment,
          failing_shipment => error
        )
      )
      client.bulk_create_orders([failing_shipment, successful_shipment])

      expect(request_runner).to have_received(:call).with(
        :post,
        "/orders/createorders",
        [serialized_shipment]
      )
    end

    it "reports any serialization errors to the error handler" do
      error_handler = instance_spy("Proc")
      shipment = build_stubbed(:shipment)
      error = RuntimeError.new("Failed to serialize shipment!")

      client = build_client(
        shipment_serializer: stub_shipment_serializer(shipment => error),
        error_handler: error_handler
      )
      client.bulk_create_orders([shipment])

      expect(error_handler).to have_received(:call).with(error, shipment: shipment)
    end

    it "skips the API call if all shipments failed serialization" do
      request_runner = instance_spy("SolidusShipstation::Api::RequestRunner")
      failing_shipment = build_stubbed(:shipment)

      client = build_client(
        shipment_serializer: stub_shipment_serializer(
          failing_shipment => RuntimeError.new("Failed to serialize shipment!")
        ),
        request_runner: request_runner
      )
      client.bulk_create_orders([failing_shipment])

      expect(request_runner).not_to have_received(:call)
    end
  end

  private

  def build_client(options = {})
    described_class.new(request_runner: instance_spy("SolidusShipstation::Api::RequestRunner"),
      error_handler: instance_spy("Proc"),
      shipment_serializer: stub_shipment_serializer, **options)
  end

  def stub_shipment_serializer(results_map = {})
    serializer = class_spy("SolidusShipstation::Api::Serializer")

    results_map.each_pair do |shipment, result_or_error|
      stub = allow(serializer).to receive(:call).with(shipment)

      if result_or_error.is_a?(Hash)
        stub.and_return(result_or_error)
      else
        stub.and_raise(result_or_error)
      end
    end

    serializer
  end
end
