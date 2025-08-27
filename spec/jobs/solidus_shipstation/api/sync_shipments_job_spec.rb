# frozen_string_literal: true

RSpec.describe SolidusShipstation::Api::SyncShipmentsJob do
  include ActiveSupport::Testing::TimeHelpers

  context 'when a shipment is syncable' do
    context 'when the sync can be completed successfully' do
      it 'syncs the provided shipments in batch' do
        shipment = build_stubbed(:shipment) { |s| stub_syncability(s, true) }
        batch_syncer = stub_successful_batch_syncer

        described_class.perform_now([shipment])

        expect(batch_syncer).to have_received(:call).with([shipment])
      end
    end

    context 'when the sync cannot be completed' do
      context 'when the error is a rate limit' do
        it 'retries intelligently when hitting a rate limit' do
          freeze_time do
            shipment = build_stubbed(:shipment) { |s| stub_syncability(s, true) }
            stub_failing_batch_syncer(SolidusShipstation::Api::RateLimitedError.new(
              response_code: 429,
              response_headers: { 'X-Rate-Limit-Reset' => 30 },
              response_body: '{"message":"Too Many Requests"}',
              retry_in: 30.seconds,
            ))

            described_class.perform_now([shipment])

            expect(described_class).to have_been_enqueued.at(30.seconds.from_now)
          end
        end
      end

      context 'when the error is a server error' do
        it 'calls the error handler' do
          error_handler = instance_spy('Proc')
          stub_configuration(error_handler: error_handler)
          shipment = build_stubbed(:shipment) { |s| stub_syncability(s, true) }
          error = SolidusShipstation::Api::RequestError.new(
            response_code: 500,
            response_headers: {},
            response_body: '{"message":"Internal Server Error"}',
          )
          stub_failing_batch_syncer(error)

          described_class.perform_now([shipment])

          expect(error_handler).to have_received(:call).with(error, {})
        end

        it 'calls the error handler after a specified amount of retries' do
          error_handler = instance_spy('Proc')
          stub_configuration(error_handler: error_handler, api_request_attempts: 3)

          # Reload the job since the api_request_attempts is set on class loading.
          load 'app/jobs/solidus_shipstation/api/sync_shipments_job.rb'

          shipment = create(:shipment) { |s| stub_syncability(s, true) }
          error = SolidusShipstation::Api::RequestError.new(
            response_code: 500,
            response_headers: {},
            response_body: '{"message":"Internal Server Error"}',
          )
          failing_batch_syncer = stub_failing_batch_syncer(error)

          # Allow enqueued jobs, since we expect the job to queue
          # retries.
          perform_enqueued_jobs(queue: :default) do
            described_class.perform_later([shipment])
          end

          expect(error_handler).to have_received(:call).once
          expect(failing_batch_syncer).to have_received(:call).exactly(3).times
        ensure
          # Reset the api_request_attempts to default for next tests.
          stub_configuration(api_request_attempts: 1)
          load 'app/jobs/solidus_shipstation/api/sync_shipments_job.rb'
        end
      end
    end
  end

  context 'when a shipment is not syncable' do
    it 'skips shipments that are not pending sync' do
      shipment = build_stubbed(:shipment) { |s| stub_syncability(s, false) }
      batch_syncer = stub_successful_batch_syncer

      described_class.perform_now([shipment])

      expect(batch_syncer).not_to have_received(:call)
    end

    it 'fires a solidus_shipstation.api.sync_skipped event' do
      shipment = build_stubbed(:shipment) { |s| stub_syncability(s, false) }

      allow(Spree::Bus).to receive(:publish).with(
        :'solidus_shipstation.api.sync_skipped',
        shipment: shipment,
      )

      stub_successful_batch_syncer

      described_class.perform_now([shipment])

      expect(Spree::Bus).to have_received(:publish).with(
        :'solidus_shipstation.api.sync_skipped',
        shipment: shipment,
      )
    end
  end

  private

  def stub_successful_batch_syncer
    instance_spy(SolidusShipstation::Api::BatchSyncer).tap do |batch_syncer|
      allow(SolidusShipstation::Api::BatchSyncer).to receive(:from_config).and_return(batch_syncer)
    end
  end

  def stub_failing_batch_syncer(error)
    instance_double(SolidusShipstation::Api::BatchSyncer).tap do |batch_syncer|
      allow(SolidusShipstation::Api::BatchSyncer).to receive(:from_config).and_return(batch_syncer)

      allow(batch_syncer).to receive(:call).and_raise(error)
    end
  end

  def stub_syncability(shipment, result)
    allow(SolidusShipstation::Api::ThresholdVerifier).to receive(:call)
      .with(shipment)
      .and_return(result)
  end
end
