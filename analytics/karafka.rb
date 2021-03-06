# frozen_string_literal: true

$stdout.sync = true

begin
  require_relative ".env"
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require_relative "models"

ENV["KARAFKA_ENV"] ||= "development"
Bundler.require(:default, ENV.fetch("KARAFKA_ENV", nil))

# Zeitwerk custom loader for loading the app components before the whole
# Karafka framework configuration
APP_LOADER = Zeitwerk::Loader.new

APP_LOADER.push_dir("#{__dir__}/karafka/consumers")

APP_LOADER.enable_reloading
APP_LOADER.setup
APP_LOADER.eager_load

require "avro_turf/messaging"
require_relative "../schema_registry/registry"

AVRO = AvroTurf::Messaging.new(registry: Registry.new)

class AvroDeserializer
  def self.call(message)
    AVRO.decode(message.raw_payload)
  end
end

# App class
class App < Karafka::App
  setup do |config|
    config.client_id = "analytics"
    config.concurrency = 5
    config.max_wait_time = 1_000
    config.kafka = { "bootstrap.servers": ENV.fetch("KAFKA_HOST", ENV.delete("ANALYTICS_KARAFKA_BROKER_URL")) }
  end
end

Karafka.producer.monitor.subscribe(WaterDrop::Instrumentation::LoggerListener.new(Karafka.logger))
# Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

App.consumer_groups.draw do
  consumer_group :batched_group do
    topic "default" do
      consumer ApplicationConsumer
    end
  end
end
