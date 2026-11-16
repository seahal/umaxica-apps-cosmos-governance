# frozen_string_literal: true

require "test_helper"

class ConfigValuesHostFamilyValuesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "base origins include service corporate and staff hosts in authority order" do
    values = ConfigValues::HostFamilyValues.new(
      base_service: "https://app.example.invalid",
      base_corporate: "https://com.example.invalid",
      base_staff: "https://org.example.invalid",
      visa_service: "https://visa.example.invalid",
      visa_staff: "https://visa-org.example.invalid",
      tech_staff: "https://tech.example.invalid",
      auth_service: "https://auth.example.invalid",
      auth_staff: "https://auth-org.example.invalid",
    )

    assert_equal ["https://app.example.invalid", "https://com.example.invalid", "https://org.example.invalid"],
                 values.base_origins
  end
end
