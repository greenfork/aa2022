# frozen_string_literal: true

begin
  require_relative ".env"
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require "sequel/core"

# Delete BILLING_DATABASE_URL from the environment, so it isn't accidently
# passed to subprocesses.  BILLING_DATABASE_URL may contain passwords.
DB = Sequel.connect(ENV.delete("BILLING_DATABASE_URL") || ENV.delete("DATABASE_URL"))
