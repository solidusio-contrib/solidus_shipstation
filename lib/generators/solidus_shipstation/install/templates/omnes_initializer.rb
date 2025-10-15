Rails.application.config.to_prepare do
  Spree::Bus.register(:"solidus_shipstation.api.sync_skipped")
  Spree::Bus.register(:"solidus_shipstation.api.rate_limited")
  Spree::Bus.register(:"solidus_shipstation.api.sync_errored")
  Spree::Bus.register(:"solidus_shipstation.api.sync_failed")
  Spree::Bus.register(:"solidus_shipstation.api.sync_completed")
end
