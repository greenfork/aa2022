# frozen_string_literal: true

require_relative "spec_helper"

describe "/" do
  it "should " do
    visit "/"
    page.title.must_equal "Task tracker"
  end
end
