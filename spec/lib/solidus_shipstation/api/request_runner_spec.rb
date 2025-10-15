RSpec.describe SolidusShipstation::Api::RequestRunner do
  describe ".from_config" do
    it "builds a runner using credentials from the configuration" do
      stub_configuration(api_key: "user", api_secret: "pass")

      request_runner = described_class.from_config

      expect(request_runner).to have_attributes(
        username: "user",
        password: "pass"
      )
    end
  end

  describe "#call" do
    context "when the response code is 2xx" do
      it "returns the parsed response" do
        stub_request(:post, %r{ssapi.shipstation.com/test}).with(
          basic_auth: %w[user pass],
          headers: {"Content-Type" => "application/json", "Accept" => "application/json"},
          body: '{"request_key":"request_value"}'
        ).to_return(
          headers: {"Content-Type" => "application/json"},
          body: '{"response_key":"response_value"}'
        )
        request_runner = described_class.new(username: "user", password: "pass")

        response = request_runner.call(:post, "/test", request_key: "request_value")

        expect(response).to eq("response_key" => "response_value")
      end
    end

    context "when the response code is 429" do
      it "raises a RateLimitedError" do
        stub_request(:post, %r{ssapi.shipstation.com/test}).to_return(
          status: 429,
          headers: {"Content-Type" => "application/json", "X-Rate-Limit-Reset" => 20},
          body: '{"message":"Too Many Requests"}'
        )
        request_runner = described_class.new(username: "user", password: "pass")

        expect {
          request_runner.call(:post, "/test")
        }.to raise_error(SolidusShipstation::Api::RateLimitedError)
      end
    end

    context "when the response code is not 200 or 429" do
      it "raises a RequestError" do
        stub_request(:post, %r{ssapi.shipstation.com/test}).to_return(
          status: 500,
          headers: {"Content-Type" => "application/json"},
          body: '{"message":"Internal Server Error"}'
        )
        request_runner = described_class.new(username: "user", password: "pass")

        expect {
          request_runner.call(:post, "/test")
        }.to raise_error(SolidusShipstation::Api::RequestError)
      end
    end
  end
end
