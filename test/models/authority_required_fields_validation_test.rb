# frozen_string_literal: true

require "test_helper"

class AuthorityRequiredFieldsValidationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Bureau name rejects nil" do
    resource = Bureau.new(name: nil)

    resource.valid?

    assert_not_empty resource.errors[:name]
  end

  test "Bureau name rejects empty" do
    resource = Bureau.new(name: "")

    resource.valid?

    assert_not_empty resource.errors[:name]
  end

  test "Bureau name accepts valid text" do
    resource = Bureau.new(name: "Authority1")

    resource.valid?

    assert_empty resource.errors[:name]
  end

  test "Bureau title rejects nil" do
    resource = Bureau.new(title: nil)

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "Bureau title rejects empty" do
    resource = Bureau.new(title: "")

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "Bureau title accepts valid text" do
    resource = Bureau.new(title: "Authority1")

    resource.valid?

    assert_empty resource.errors[:title]
  end

  test "Enterprise name rejects nil" do
    resource = Enterprise.new(name: nil)

    resource.valid?

    assert_not_empty resource.errors[:name]
  end

  test "Enterprise name rejects empty" do
    resource = Enterprise.new(name: "")

    resource.valid?

    assert_not_empty resource.errors[:name]
  end

  test "Enterprise name accepts valid text" do
    resource = Enterprise.new(name: "Authority1")

    resource.valid?

    assert_empty resource.errors[:name]
  end

  test "Enterprise title rejects nil" do
    resource = Enterprise.new(title: nil)

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "Enterprise title rejects empty" do
    resource = Enterprise.new(title: "")

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "Enterprise title accepts valid text" do
    resource = Enterprise.new(title: "Authority1")

    resource.valid?

    assert_empty resource.errors[:title]
  end

  test "Agent title rejects nil" do
    resource = Agent.new(title: nil)

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "Agent title rejects empty" do
    resource = Agent.new(title: "")

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "Agent title accepts valid text" do
    resource = Agent.new(title: "Authority1")

    resource.valid?

    assert_empty resource.errors[:title]
  end

  test "ClientPersona title rejects nil" do
    resource = ClientPersona.new(title: nil)

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "ClientPersona title rejects empty" do
    resource = ClientPersona.new(title: "")

    resource.valid?

    assert_not_empty resource.errors[:title]
  end

  test "ClientPersona title accepts valid text" do
    resource = ClientPersona.new(title: "Authority1")

    resource.valid?

    assert_empty resource.errors[:title]
  end
end
