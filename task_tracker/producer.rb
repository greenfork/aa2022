# frozen_string_literal: true

require_relative "broker"
require_relative "../schema_registry/registry"

require "avro_turf/messaging"
require "dry/inflector"
require "securerandom"

class Producer
  AVRO = AvroTurf::Messaging.new(registry: Registry.new)
  INFL = Dry::Inflector.new

  def self.call(events, topic:)
    case events
    when Hash
      events[:event_id] = SecureRandom.uuid
      events[:event_version] = 1
      events[:event_timestamp] = Time.now.to_i * 1000
      events[:producer] = "task_tracker"
      BROKER.produce_sync(
        topic:,
        payload: AVRO.encode(
          events,
          subject: INFL.underscore(events[:event_name]),
          version: "latest",
          validate: true
        )
      )
    when Array
      BROKER.produce_many_sync(
        events.map do |event|
          event[:event_id] = SecureRandom.uuid
          event[:event_version] = 1
          event[:event_timestamp] = Time.now.to_i * 1000
          event[:producer] = "task_tracker"
          {
            topic:,
            payload: AVRO.encode(
              event,
              subject: INFL.underscore(event[:event_name]),
              version: "latest",
              validate: true
            )
          }
        end
      )
    end
  end
end
