# frozen_string_literal: true

require "avro_turf/messaging"
require_relative "../schema_registry/registry"

SERIALIZER = AvroTurf::Messaging.new(registry: Registry.new)
