# frozen_string_literal: true

Sequel.migration do
  up do
    db = self
    extension :pg_enum
    create_enum :account_role, %w[employee manager accountant admin]

    run "CREATE EXTENSION IF NOT EXISTS citext" if db.database_type == :postgres

    create_table(:accounts) do
      primary_key :id, type: :Bigint
      uuid :public_id, unique: true, null: false
      if db.database_type == :postgres
        citext :email, null: false
        constraint :valid_email, email: /^[^,;@ \r\n]+@[^,@; \r\n]+\.[^,@; \r\n]+$/
      else
        String :email, null: false
      end
      String :full_name, null: false, default: ""
      account_role :role, null: false, default: "employee"
    end
  end

  down do
    drop_table :accounts

    extension :pg_enum
    drop_enum :account_role
  end
end
