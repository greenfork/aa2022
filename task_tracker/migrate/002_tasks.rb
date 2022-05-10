# frozen_string_literal: true

Sequel.migration do
  up do
    extension :pg_enum
    create_enum :task_status, %w[open closed]

    create_table(:tasks) do
      primary_key :id
      String :description, null: false, default: ""
      task_status :status, null: false, default: "open"
      uuid :assignee_public_id, null: false
    end
  end

  down do
    drop_table :tasks

    extension :pg_enum
    drop_enum :task_status
  end
end
