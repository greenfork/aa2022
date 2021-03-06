# frozen_string_literal: true

class TasksStreamConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload["data"]
      case [message.payload["event_name"], message.payload["event_version"]]
      when ["TaskCreated", 1]
        Task.create_or_update(data)
      end
    end
  end
end
