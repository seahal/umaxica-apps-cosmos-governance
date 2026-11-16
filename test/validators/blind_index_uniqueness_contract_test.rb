# frozen_string_literal: true

require "test_helper"
require "database_consistency"

class BlindIndexUniquenessContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "checker recognizes existing exact digest uniqueness enforcement on both operator contacts" do
    [[OperatorEmail, :address_digest], [OperatorTelephone, :number_digest]].each do |model, column|
      index =
        model.connection_pool.with_connection do |connection|
          connection.indexes(model.table_name).find { |candidate|
            candidate.unique && candidate.columns == [column.to_s]
          }
        end

      assert index
      report = DatabaseConsistency::Checkers::UniqueIndexChecker.new(model, index).report(catch_errors: false)

      assert_equal :ok, report.status
      validator = model.validators_on(column).find { |candidate| candidate.is_a?(BlindIndexUniquenessValidator) }
      inverse_report = DatabaseConsistency::Checkers::MissingUniqueIndexChecker.new(model, column, validator)
        .report(catch_errors: false)

      assert_equal :ok, inverse_report.status
    end
  end

  test "email digest duplicates retain address errors one preflight query and PostgreSQL enforcement" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    existing = OperatorEmail.create!(staff: staff, address: "blind-index-contract@example.test", confirm_policy: true)
    duplicate = existing.dup
    duplicate.public_id = PublicId.generate
    queries = []
    subscriber =
      ->(_name, _start, _finish, _id, payload) {
        queries << payload[:sql] if payload[:sql].match?(/SELECT.*operator_emails.*address_digest/i)
      }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { duplicate.valid? }

    assert duplicate.errors.of_kind?(:address, :taken)
    assert_not duplicate.errors.include?(:address_digest)
    assert_equal 1, queries.length
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorEmail.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "telephone digest duplicates retain number errors one preflight query and PostgreSQL enforcement" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    existing = OperatorTelephone.create!(
      staff: staff, number: "+819033330001", confirm_policy: true, confirm_using_mfa: true,
    )
    duplicate = existing.dup
    duplicate.public_id = PublicId.generate
    queries = []
    subscriber =
      ->(_name, _start, _finish, _id, payload) {
        queries << payload[:sql] if payload[:sql].match?(/SELECT.*operator_telephones.*number_digest/i)
      }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { duplicate.valid? }

    assert duplicate.errors.of_kind?(:number, :taken)
    assert_not duplicate.errors.include?(:number_digest)
    assert_equal 1, queries.length
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorTelephone.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end
end
