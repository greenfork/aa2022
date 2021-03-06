# frozen_string_literal: true

Sequel.migration do
  up do
    extension :pg_enum
    create_enum :transaction_type, %w[deposit withdraw payment]
    create_enum :payment_status, %w[scheduled completed failed]

    create_table(:transactions) do
      primary_key :id, type: :Bigint
      uuid :public_id, unique: true, null: false, default: Sequel.function(:gen_random_uuid)
      uuid :account_public_id, null: false
      transaction_type :type, null: false
      DateTime :performed_at, null: false, default: Sequel.function(:now)
      Integer :debit, null: false, default: 0
      Integer :credit, null: false, default: 0
    end

    create_table(:payments) do
      primary_key :id, type: :Bigint
      uuid :public_id, unique: true, null: false, default: Sequel.function(:gen_random_uuid)
      uuid :transaction_public_id, null: false
      payment_status :status, null: false
    end
  end

  down do
    drop_table :payments
    drop_table :transactions

    extension :pg_enum
    drop_enum :transaction_type
    drop_enum :payment_status
  end
end
