# frozen_string_literal: true

module SolidusShipstation
  module Api
    class RateLimitedError < RequestError
      attr_reader :retry_in

      class << self
        def options_from_response(response)
          super.merge(
            retry_in: response.headers["X-Rate-Limit-Reset"].to_i.seconds
          )
        end
      end

      def initialize(retry_in:, **options)
        super(**options)

        @retry_in = retry_in
      end
    end
  end
end
