# frozen_string_literal: true

require "test_helper"

class IdentifierRotationAuditUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [
    [ClientIdentifierRotationAudit, "client_rotation_operation", Client, ClientEmail, :user,
     "public.rotate_client_emails_hmac", "umaxica_app_email_hmac_definer_", ClientStatus::ACTIVE,],
    [OperatorIdentifierRotationAudit, "operator_rotation_operation", Operator, OperatorEmail, :staff,
     "public.rotate_operator_emails_hmac", "umaxica_org_email_hmac_definer_", OperatorStatus::ACTIVE,],
  ].each do |model, constraint, owner_model, identifier_model, owner_key, function, prefix, status|
    test "#{model.name} reserves the source tuple without bypassing its maintenance boundary" do
      owner = owner_model.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status)
      identifier = identifier_model.create!(
        owner_key => owner, :raw_address => "rotation-uniqueness@example.com", :confirm_policy => true,
      )
      identifier.tap { |binding_record|
        binding_record.update!(binding_finalized_at: Time.current)
      } if identifier_model == ClientEmail
      connection = model.lease_connection
      raw = connection.raw_connection
      definer = raw.exec_params(
        "SELECT r.rolname FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_roles r ON r.oid=p.proowner " \
        "WHERE p.oid=$1::regprocedure", ["#{function}(bigint,text,text,uuid)"],
      ).getvalue(0, 0)

      assert_match(/\A#{Regexp.escape(prefix)}[0-9a-f]{12}\z/, definer)
      caller_role = definer.sub("_definer_", "_caller_")
      operation = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a31"
      previous_digest = identifier.reload.address_digest
      model.transaction(requires_new: true) do
        connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
        raw.exec_params("SELECT #{function}($1,$2,$3,$4)", [identifier.id, "a" * 64, previous_digest, operation])
        connection.execute("RESET ROLE")
      end
      original = model.find_by!(operation_ref: operation, channel: "email", record_id: identifier.id)
      attributes = original.attributes.except("id")
      duplicate = model.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:operation_ref, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate original, :valid?
      error =
        assert_raises(PG::UniqueViolation) do
          model.transaction(requires_new: true) do
            connection.execute("SET LOCAL ROLE #{connection.quote_column_name(caller_role)}")
            raw.exec_params("SELECT #{function}($1,$2,$3,$4)", [identifier.id, "b" * 64, "a" * 64, operation])
          end
        end

      assert_equal constraint, error.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      digest_preserved = identifier.reload.address_digest == "a" * 64

      assert digest_preserved
      assert_equal 1, model.where(operation_ref: operation, channel: "email", record_id: identifier.id).count
      other_record = model.new(attributes.merge("record_id" => identifier.id + 1))
      other_channel = model.new(attributes.merge("channel" => "telephone"))
      other_operation = model.new(attributes.merge("operation_ref" => "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a32"))

      assert_predicate other_record, :valid?
      assert_predicate other_channel, :valid?
      assert_predicate other_operation, :valid?
      # Valid AR attributes do not confer the maintenance function's insertion privilege.
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          model.transaction(requires_new: true) { other_operation.save!(validate: false) }
        end

      assert_kind_of PG::RaiseException, error.cause
      assert_includes error.message, "identifier rotation audit requires its domain function"
      assert_raises(ActiveRecord::ReadOnlyRecord) { original.update!(actor_role: "forbidden-update") }
      assert_equal raw.user, original.reload.actor_role
    end
  end
end
