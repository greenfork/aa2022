# frozen_string_literal: true

class AccountsStreamConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload["data"]
      case [message.payload["event_name"], message.payload["event_version"]]
      when ["AccountCreated", 1]
        Account.create(
          full_name: data["full_name"],
          role: data["role"],
          email: data["email"],
          public_id: data["public_id"]
        )
      when ["AccountUpdated", 1]
        Account.where(public_id: data["public_id"]).update(
          email: data["email"],
          full_name: data["full_name"]
        )
      when ["AccountDeleted", 1]
        Account.where(public_id: data["public_id"]).delete
      end
    end
  end
end
