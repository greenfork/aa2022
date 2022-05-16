# frozen_string_literal: true

require "json"
require "logger"

class Registry
  SUBJECTS_DIR = "#{__dir__}/subjects".freeze

  attr_reader :schemas, :schema_ids

  def initialize
    @schemas = []
    @schema_ids = {}
    @logger = Logger.new($stdout)
    Dir.each_child(SUBJECTS_DIR) do |subject|
      Dir.each_child("#{SUBJECTS_DIR}/#{subject}") do |schema|
        version_number = File.basename(schema, File.extname(schema)).to_i
        file_path = "#{SUBJECTS_DIR}/#{subject}/#{schema}"
        @schemas.push(
          {
            "subject" => subject,
            "version" => version_number,
            "id" => schemas.size,
            "schema" => JSON.parse(File.read(file_path)).to_json
          }
        )
        @schema_ids[subject] ||= {}
        @schema_ids[subject][version_number] = schemas.size - 1
      end
    end
  end

  def fetch(id)
    @logger.info "Fetching schema with id #{id}"
    schemas[id]["schema"]
  end

  def register(_subject, _schema)
    raise "Not implemented"
  end

  # List all subjects
  def subjects
    schema_ids.keys
  end

  # List all versions for a subject
  def subject_versions(subject)
    schema_ids[subject].keys
  end

  # Get a specific version for a subject
  def subject_version(subject, version = "latest")
    if version == "latest"
      latest_version = schema_ids[subject].keys.max
      schemas[schema_ids[subject][latest_version]]
    else
      schemas[schema_ids[subject][version.to_i]]
    end
  end

  # Check if a schema exists. Returns nil if not found.
  def check(subject, _schema)
    schema_ids[subject]
  end

  # Check if a schema is compatible with the stored version.
  # Returns:
  # - true if compatible
  # - nil if the subject or version does not exist
  # - false if incompatible
  # http://docs.confluent.io/3.1.2/schema-registry/docs/api.html#compatibility
  def compatible?(_subject, _schema, _version = "latest")
    raise "Not implemented"
  end

  # Get global config
  def global_config
    raise "Not implemented"
  end

  # Update global config
  def update_global_config(_config)
    raise "Not implemented"
  end

  # Get config for subject
  def subject_config(_subject)
    raise "Not implemented"
  end

  # Update config for subject
  def update_subject_config(_subject, _config)
    raise "Not implemented"
  end
end
