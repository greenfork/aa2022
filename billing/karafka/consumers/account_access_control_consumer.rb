# frozen_string_literal: true

class AccountAccessControlConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload["data"]
      case [message.payload["event_name"], message.payload["event_version"]]
      when ["AccountRoleChanged", 1]
        Account.where(public_id: data["public_id"]).update(role: data["role"])
      end
    end
  end
end
