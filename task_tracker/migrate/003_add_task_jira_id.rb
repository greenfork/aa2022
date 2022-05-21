# frozen_string_literal: true

Sequel.migration do
  change do
    add_column :tasks, :jira_id, String, null: false, default: ""
  end
end
