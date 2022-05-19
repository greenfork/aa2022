# frozen_string_literal: true

class TasksStreamConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload["data"]
      case message.payload["event_name"]
      when "TaskCreated"
        Task.create_or_update(data)
      end
    end
  end
end
