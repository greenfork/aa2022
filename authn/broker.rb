# frozen_string_literal: true

begin
  require_relative ".env"
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require "waterdrop"

BROKER = WaterDrop::Producer.new
BROKER.setup do |config|
  config.kafka = { "bootstrap.servers": ENV.delete("AUTHN_BROKER_URL") }
end
