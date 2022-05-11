# frozen_string_literal: true

class AccountsStreamConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload["data"]
      case message.payload["name"]
      when "AccountCreated"
        Account.create(
          full_name: data["full_name"],
          role: data["role"],
          email: data["email"],
          public_id: data["public_id"]
        )
      when "AccountUpdated"
        Account.where(public_id: data["public_id"]).update(
          email: data["email"],
          full_name: data["full_name"]
        )
      when "AccountDeleted"
        Account.where(public_id: data["public_id"]).delete
      end
    end
  end
end
