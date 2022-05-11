# frozen_string_literal: true

require "json"
require_relative "broker"

class Producer
  def self.call(event, topic:)
    json_event = event.to_json
    puts "*" * 80
    puts "Send to #{topic}: #{json_event}"
    puts "*" * 80
    BROKER.produce_sync(topic:, payload: json_event)
  end

  def self.produce_many_single_topic(events, topic:)
    puts "*" * 80
    puts "Send to #{topic}: #{events.size} events"
    puts "*" * 80
    BROKER.produce_many_sync(events.map { { payload: _1.to_json, topic: } })
  end
end
