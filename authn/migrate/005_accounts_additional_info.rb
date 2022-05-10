# frozen_string_literal: true

Sequel.migration do
  up do
    extension :pg_enum
    create_enum :account_role, %w[employee manager accountant admin]

    run "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    alter_table :accounts do
      add_column :full_name, String, null: false, default: ""
      add_column :role, :account_role, null: false, default: "employee"
      add_column :public_id, :uuid, null: false, unique: true, default: Sequel.function(:gen_random_uuid)
    end
  end

  down do
    alter_table :accounts do
      drop_column :full_name
      drop_column :role
      drop_column :public_id
    end

    extension :pg_enum
    drop_enum :account_role
  end
end
