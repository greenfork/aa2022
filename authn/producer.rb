# frozen_string_literal: true

require "json"

class Producer
  def self.call(event, topic:)
    puts "#{topic}: #{event.to_json}"
  end
end
