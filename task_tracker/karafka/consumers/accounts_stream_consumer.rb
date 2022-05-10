# frozen_string_literal: true

class AccountsStreamConsumer < ApplicationConsumer
  def consume
    puts "*" * 80
    messages.each do |message|
      puts
      pp message.payload
      puts

      data = message.payload["data"]
      case message.payload["name"]
      when "AccountCreated"
        Account.create(
          full_name: data["full_name"],
          role: data["role"],
          email: data["email"],
          public_id: data["public_id"]
        )
      end
    end
  end
end
