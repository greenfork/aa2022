# frozen_string_literal: true

require "json"
require_relative "broker"

class Producer
  def self.call(events, topic:)
    case events
    when Hash
      BROKER.produce_sync(topic:, payload: events.to_json)
    when Array
      BROKER.produce_many_sync(events.map { { payload: _1.to_json, topic: } })
    else
      raise "Incompatible type"
    end
  end
end
