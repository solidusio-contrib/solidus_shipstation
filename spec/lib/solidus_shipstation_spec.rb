require "spec_helper"

RSpec.describe SolidusShipstation do
  describe "VERSION" do
    it "is defined" do
      expect(SolidusShipstation::VERSION).to be_present
    end
  end
end
