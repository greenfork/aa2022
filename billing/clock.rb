# frozen_string_literal: true

require_relative "models"

$stdout.sync = true

schedule.every("5 minutes") do
  now = Time.now
  next if now.hour != 0 || now.minute > 5

  puts "Running close billing cycle"
  Transaction.close_billing_cycle
end
