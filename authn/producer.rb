# frozen_string_literal: true

require_relative "broker"
require_relative "../schema_registry/registry"

require "avro_turf/messaging"
require "dry/inflector"
require "securerandom"

class Producer
  AVRO = AvroTurf::Messaging.new(registry: Registry.new)
  INFL = Dry::Inflector.new

  def self.call(event, topic:)
    event[:event_id] = SecureRandom.uuid
    event[:event_version] = 1
    event[:event_timestamp] = Time.now.to_i * 1000
    event[:producer] = "authn"
    BROKER.produce_sync(
      topic:,
      payload: AVRO.encode(
        event,
        subject: INFL.underscore(event[:event_name]),
        version: "latest",
        validate: true
      )
    )
  end
end
