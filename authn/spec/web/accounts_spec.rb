# frozen_string_literal: true

require_relative "spec_helper"

describe "/accounts" do
  it "should " do
    visit "/"
    page.title.must_equal "Authn"
  end
end
