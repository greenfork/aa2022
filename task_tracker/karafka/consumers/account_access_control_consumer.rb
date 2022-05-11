# frozen_string_literal: true

class AccountAccessControlConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload["data"]
      case message.payload["name"]
      when "AccountRoleChanged"
        Account.where(public_id: data["public_id"]).update(role: data["role"])
      end
    end
  end
end
