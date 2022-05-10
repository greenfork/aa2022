# frozen_string_literal: true

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

%w[karafka/consumers].each(&APP_LOADER.method(:push_dir))

APP_LOADER.setup
APP_LOADER.eager_load

# App class
class App < Karafka::App
  setup do |config|
    config.concurrency = 5
    config.max_wait_time = 1_000
    config.kafka = { "bootstrap.servers": ENV.fetch("KAFKA_HOST", ENV.delete("AUTHN_KARAFKA_BROKER_URL")) }
  end
end

Karafka.producer.monitor.subscribe(WaterDrop::Instrumentation::LoggerListener.new(Karafka.logger))
Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

App.consumer_groups.draw do
  consumer_group :batched_group do
    topic "accounts-stream" do
      consumer AccountsStreamConsumer
    end
  end
end
