RSpec.describe SolidusShipstation::Api::RateLimitedError do
  describe ".from_response" do
    it "extracts the status code, body, headers and retry time from the response" do
      response = instance_double(
        "HTTParty::Response",
        code: 429,
        headers: {"X-Rate-Limit-Reset" => 20},
        body: '{ "message": "Too Many Requests" }'
      )

      error = described_class.from_response(response)

      expect(error).to have_attributes(
        response_code: 429,
        response_headers: {"X-Rate-Limit-Reset" => 20},
        response_body: '{ "message": "Too Many Requests" }',
        retry_in: 20.seconds
      )
    end
  end
end
