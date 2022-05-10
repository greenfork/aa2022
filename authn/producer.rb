# frozen_string_literal: true

require "json"
require_relative "broker"

class Producer
  def self.call(event, topic:)
    puts "*" * 80
    puts "Send to #{topic}: #{event.to_json}"
    puts "*" * 80
    BROKER.produce_sync(topic:, payload: event.to_json)
  end
end
