# frozen_string_literal: true

class Account < Sequel::Model
  ROLES = %w[employee manager accountant admin].freeze
end

# Table: accounts
# Columns:
#  id        | bigint       | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  public_id | uuid         | NOT NULL
#  email     | citext       | NOT NULL
#  full_name | text         | NOT NULL DEFAULT ''::text
#  role      | account_role | NOT NULL DEFAULT 'employee'::account_role
# Indexes:
#  accounts_pkey          | PRIMARY KEY btree (id)
#  accounts_public_id_key | UNIQUE btree (public_id)
# Check constraints:
#  valid_email | (email ~ '^[^,;@ \r\n]+@[^,@; \r\n]+\.[^,@; \r\n]+$'::citext)