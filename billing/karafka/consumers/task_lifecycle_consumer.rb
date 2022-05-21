# frozen_string_literal: true

require "securerandom"
require_relative "../../serializer"

class TaskLifecycleConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload["data"]
      case [message.payload["event_name"], message.payload["event_version"]]
      when ["TaskAdded", 1]
        task, transaction = Task.add(
          public_id: data["public_id"],
          assignee_public_id: data["assignee_public_id"]
        )
        task_payload = SERIALIZER.encode(
          {
            event_name: "TaskCostCreated",
            event_id: SecureRandom.uuid,
            event_version: 1,
            event_timestamp: Time.now.to_i * 1000,
            producer: "billing",
            data: {
              task_public_id: task.public_id,
              cost: task.cost,
              reward: task.reward
            }
          },
          subject: "task_cost_created",
          version: 1
        )
        producer.produce_sync(topic: "task-costs-stream", payload: task_payload)
        producer.produce_sync(topic: "billing-transactions", payload: transaction_payload(task, transaction))
      when ["TaskClosed", 1]
        task, transaction = Task.close(public_id: data["public_id"])
        if !task.nil? && !transaction.nil?
          producer.produce_sync(topic: "billing-transactions", payload: transaction_payload(task, transaction))
        end
      when ["TaskShuffled", 1]
        task, transaction = Task.change_assignee(
          public_id: data["public_id"],
          assignee_public_id: data["assignee_public_id"]
        )
        if !task.nil? && !transaction.nil?
          producer.produce_sync(topic: "billing-transactions", payload: transaction_payload(task, transaction))
        end
      end
    end
  end

  private

  def transaction_event_template(task, transaction)
    {
      event_name: "TransactionApplied",
      event_id: SecureRandom.uuid,
      event_version: 1,
      event_timestamp: Time.now.to_i * 1000,
      producer: "billing",
      data: {
        public_id: transaction.public_id,
        task_public_id: task.public_id,
        account_public_id: transaction.account_public_id,
        type: transaction.type,
        debit: transaction.debit,
        credit: transaction.credit,
        performed_at: transaction.performed_at.to_i * 1000
      }
    }
  end

  def transaction_payload(task, transaction)
    SERIALIZER.encode(
      transaction_event_template(task, transaction),
      subject: "transaction_applied",
      version: 1
    )
  end
end
