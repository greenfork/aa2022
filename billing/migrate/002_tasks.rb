# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:tasks) do
      primary_key :id
      String :description, null: false, default: ""
      uuid :assignee_public_id
      uuid :public_id, null: false, unique: true, default: Sequel.function(:gen_random_uuid)
      Integer :cost
      Integer :reward
    end
  end
end
