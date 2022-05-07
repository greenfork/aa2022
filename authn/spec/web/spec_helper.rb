# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
require_relative "../../app"
raise "test database doesn't end with test" unless DB.opts[:database] =~ /test\z/

require "capybara"
require "capybara/dsl"
require "rack/test"

Gem.suffix_pattern

require_relative "../minitest_helper"

begin
  require "refrigerator"
rescue LoadError # rubocop:disable Lint/SuppressedException
else
  Refrigerator.freeze_core
end

Authn.plugin :not_found do
  raise "404 - File Not Found"
end
Authn.plugin :error_handler do |e|
  raise e
end

Capybara.app = Authn.freeze.app
Capybara.exact = true

class Minitest::HooksSpec
  include Rack::Test::Methods
  include Capybara::DSL

  def app
    Capybara.app
  end

  after do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end
