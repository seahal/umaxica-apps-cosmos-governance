# frozen_string_literal: true

require "test_helper"

class ContactBindingUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "only effective contacts reserve normalized destinations across owners" do
    [[ClientEmail, :address, :address_digest, "binding-contract@example.test"],
     [ClientTelephone, :number, :number_digest, "+819033330011"],].each do |model, value_key, digest_key, destination|
      owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      attributes = { value_key => destination, :confirm_policy => true }
      attributes[:confirm_using_mfa] = true if model == ClientTelephone
      first = model.create!(attributes.merge(user: owner))
      second = model.create!(attributes.merge(user: other))

      assert_predicate second, :valid?
      first.tap { |binding_record| binding_record.update!(binding_finalized_at: Time.current) }
      second.binding_finalized_at = model.database_now

      assert_predicate second, :invalid?
      assert second.errors.of_kind?(value_key, :taken)
      assert_not second.errors.include?(digest_key)
      assert_not second.errors.include?(:user_id)
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) { second.save!(validate: false) }
      end
      first.release_binding!
      second.reload.tap { |binding_record| binding_record.update!(binding_finalized_at: Time.current) }

      assert_predicate second.reload, :binding_effective?
      assert_predicate first.reload, :binding_released?
    end
  end

  test "only effective contacts reserve the owner across different destinations" do
    [[ClientEmail, :address, "owner-first@example.test", "owner-second@example.test"],
     [ClientTelephone, :number, "+819033330012",
      "+819033330013",],].each do |model, value_key, first_value, second_value|
      owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      attributes = { user: owner, confirm_policy: true }
      attributes[:confirm_using_mfa] = true if model == ClientTelephone
      first = model.create!(attributes.merge(value_key => first_value))
      second = model.create!(attributes.merge(value_key => second_value))
      first.tap { |binding_record| binding_record.update!(binding_finalized_at: Time.current) }
      second.binding_finalized_at = model.database_now

      assert_predicate second, :invalid?
      assert second.errors.of_kind?(:user_id, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) { second.save!(validate: false) }
      end
      first.release_binding!
      second.reload.tap { |binding_record| binding_record.update!(binding_finalized_at: Time.current) }

      assert_equal second.id, model.effective_binding.find_by!(user_id: owner.id).id
    end
  end

  test "unchanged effective contact validation adds no unique destination or owner probe" do
    [[ClientEmail, :address, "unchanged-binding@example.test"],
     [ClientTelephone, :number, "+819033330014"],].each do |model, value_key, destination|
      owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
      attributes = { :user => owner, value_key => destination, :confirm_policy => true }
      attributes[:confirm_using_mfa] = true if model == ClientTelephone
      contact = model.create!(attributes)
      contact.tap { |binding_record| binding_record.update!(binding_finalized_at: Time.current) }
      queries = []
      subscriber =
        ->(_name, _start, _finish, _id, payload) {
          queries << true if payload[:sql].match?(/SELECT.*FROM .*client_(emails|telephones)/i)
        }

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { assert_predicate contact, :valid? }

      assert_empty queries
    end
  end
end
