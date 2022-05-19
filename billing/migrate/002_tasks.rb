# frozen_string_literal: true

Sequel.migration do
  up do
    extension :pg_enum
    create_enum :task_status, %w[open closed]

    create_table(:tasks) do
      primary_key :id
      String :description, null: false, default: ""
      task_status :status
      uuid :assignee_public_id
      uuid :public_id, null: false, unique: true, default: Sequel.function(:gen_random_uuid)
      BigDecimal :cost, size: [10, 2]
    end
  end

  down do
    drop_table :tasks

    extension :pg_enum
    drop_enum :task_status
  end
end
