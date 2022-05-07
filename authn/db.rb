# frozen_string_literal: true

begin
  require_relative ".env"
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require "sequel/core"

# Delete AUTHN_DATABASE_URL from the environment, so it isn't accidently
# passed to subprocesses.  AUTHN_DATABASE_URL may contain passwords.
DB = Sequel.connect(ENV.delete("AUTHN_DATABASE_URL") || ENV.delete("DATABASE_URL"))
