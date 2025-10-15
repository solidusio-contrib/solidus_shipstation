RSpec.describe SolidusShipstation::Api::BatchSyncer do
  include ActiveSupport::Testing::TimeHelpers

  describe ".from_config" do
    it "creates a syncer with the configured API client" do
      client = instance_double(SolidusShipstation::Api::Client)
      allow(SolidusShipstation::Api::Client).to receive(:from_config).and_return(client)
      shipment_matcher = -> {}
      stub_configuration(api_shipment_matcher: shipment_matcher)

      batch_syncer = described_class.from_config

      expect(batch_syncer).to have_attributes(
        client: client,
        shipment_matcher: shipment_matcher
      )
    end
  end

  describe "#call" do
    context "when the API call is successful" do
      context "when the sync operation succeeded" do
        it "updates the ShipStation data on the shipment" do
          freeze_time do
            shipment = instance_spy("Spree::Shipment", number: "H123456")
            api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
              allow(client).to receive(:bulk_create_orders).with([shipment]).and_return(
                {
                  "results" => [
                    {
                      "orderNumber" => shipment.number,
                      "success" => true,
                      "orderId" => "123456"
                    }
                  ]
                }
              )
            end

            build_batch_syncer(client: api_client).call([shipment])

            expect(shipment).to have_received(:update_columns).with(
              shipstation_order_id: "123456",
              shipstation_synced_at: Time.zone.now
            )
          end
        end

        it "emits a solidus_shipstation.api.sync_completed event" do
          shipment = instance_spy("Spree::Shipment", number: "H123456")

          allow(Spree::Bus).to receive(:publish).with(
            :"solidus_shipstation.api.sync_completed",
            shipment: shipment,
            payload: {
              "orderNumber" => shipment.number,
              "success" => true,
              "orderId" => "123456"
            }
          )

          api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
            allow(client).to receive(:bulk_create_orders).with([shipment]).and_return(
              {
                "results" => [
                  {
                    "orderNumber" => shipment.number,
                    "success" => true,
                    "orderId" => "123456"
                  }
                ]
              }
            )
          end

          build_batch_syncer(client: api_client).call([shipment])

          expect(Spree::Bus).to have_received(:publish).with(
            :"solidus_shipstation.api.sync_completed",
            shipment: shipment,
            payload: {
              "orderNumber" => shipment.number,
              "success" => true,
              "orderId" => "123456"
            }
          )
        end
      end

      context "when the sync operation failed" do
        it "does not update the ShipStation data on the shipment" do
          shipment = instance_spy("Spree::Shipment", number: "H123456")
          api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
            allow(client).to receive(:bulk_create_orders).with([shipment]).and_return(
              {
                "results" => [
                  {
                    "orderNumber" => shipment.number,
                    "success" => false,
                    "orderId" => "123456"
                  }
                ]
              }
            )
          end

          build_batch_syncer(client: api_client).call([shipment])

          expect(shipment).not_to have_received(:update_columns)
        end

        it "emits a solidus_shipstation.api.sync_failed event" do
          shipment = instance_spy("Spree::Shipment", number: "H123456")

          allow(Spree::Bus).to receive(:publish).with(
            :"solidus_shipstation.api.sync_failed",
            shipment: shipment,
            payload: {
              "orderNumber" => shipment.number,
              "success" => false,
              "orderId" => "123456"
            }
          )

          api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
            allow(client).to receive(:bulk_create_orders).with([shipment]).and_return(
              {
                "results" => [
                  {
                    "orderNumber" => shipment.number,
                    "success" => false,
                    "orderId" => "123456"
                  }
                ]
              }
            )
          end

          build_batch_syncer(client: api_client).call([shipment])

          expect(Spree::Bus).to have_received(:publish).with(
            :"solidus_shipstation.api.sync_failed",
            shipment: shipment,
            payload: {
              "orderNumber" => shipment.number,
              "success" => false,
              "orderId" => "123456"
            }
          )
        end
      end
    end

    context "when the API call hits a rate limit" do
      it "emits a solidus_shipstation.api.rate_limited event" do
        shipment = instance_double("Spree::Shipment")

        error = SolidusShipstation::Api::RateLimitedError.new(
          response_headers: {"X-Rate-Limit-Reset" => 20},
          response_body: '{"message":"Too Many Requests"}',
          response_code: 429,
          retry_in: 20.seconds
        )

        allow(Spree::Bus).to receive(:publish).with(
          :"solidus_shipstation.api.rate_limited",
          shipments: [shipment],
          error: error
        )

        api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
          allow(client).to receive(:bulk_create_orders).with([shipment]).and_raise(error)
        end

        begin
          build_batch_syncer(client: api_client).call([shipment])
        rescue SolidusShipstation::Api::RateLimitedError
          # We want to ignore the error here, since we're testing for the event.
        end

        expect(Spree::Bus).to have_received(:publish).with(
          :"solidus_shipstation.api.rate_limited",
          shipments: [shipment],
          error: error
        )
      end

      it "re-raises the error" do
        shipment = instance_double("Spree::Shipment")
        error = SolidusShipstation::Api::RateLimitedError.new(
          response_headers: {"X-Rate-Limit-Reset" => 20},
          response_body: '{"message":"Too Many Requests"}',
          response_code: 429,
          retry_in: 20.seconds
        )
        api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
          allow(client).to receive(:bulk_create_orders).with([shipment]).and_raise(error)
        end

        expect {
          build_batch_syncer(client: api_client).call([shipment])
        }.to raise_error(error)
      end
    end

    context "when the API call results in a server error" do
      it "emits a solidus_shipstation.api.sync_errored event" do
        shipment = instance_double("Spree::Shipment")
        error = SolidusShipstation::Api::RequestError.new(
          response_headers: {},
          response_body: '{"message":"Internal Server Error"}',
          response_code: 500
        )

        allow(Spree::Bus).to receive(:publish).with(
          :"solidus_shipstation.api.sync_errored",
          shipments: [shipment],
          error: error
        )

        api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
          allow(client).to receive(:bulk_create_orders).with([shipment]).and_raise(error)
        end

        begin
          build_batch_syncer(client: api_client).call([shipment])
        rescue SolidusShipstation::Api::RequestError
          # We want to ignore the error here, since we're testing for the event.
        end

        expect(Spree::Bus).to have_received(:publish).with(
          :"solidus_shipstation.api.sync_errored",
          shipments: [shipment],
          error: error
        )
      end

      it "re-raises the error" do
        shipment = instance_double("Spree::Shipment")
        error = SolidusShipstation::Api::RequestError.new(
          response_headers: {},
          response_body: '{"message":"Internal Server Error"}',
          response_code: 500
        )

        allow(Spree::Bus).to receive(:publish).with(
          :"solidus_shipstation.api.sync_errored",
          shipments: [shipment],
          error: error
        )

        api_client = instance_double(SolidusShipstation::Api::Client).tap do |client|
          allow(client).to receive(:bulk_create_orders).with([shipment]).and_raise(error)
        end

        expect {
          build_batch_syncer(client: api_client).call([shipment])
        }.to raise_error(error)
      end
    end
  end

  private

  def build_batch_syncer(client:, shipment_matcher: ->(_, shipments) { shipments.first })
    described_class.new(client: client, shipment_matcher: shipment_matcher)
  end
end
