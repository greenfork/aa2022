# frozen_string_literal: true

begin
  require_relative ".env"
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require "sequel/core"

# Delete TASK_TRACKER_DATABASE_URL from the environment, so it isn't accidently
# passed to subprocesses.  TASK_TRACKER_DATABASE_URL may contain passwords.
DB = Sequel.connect(ENV.delete("TASK_TRACKER_DATABASE_URL") || ENV.delete("DATABASE_URL"))
