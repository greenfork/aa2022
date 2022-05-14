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
end
