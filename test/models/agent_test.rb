# frozen_string_literal: true

require "test_helper"

class AgentTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::Agent)
  end

  test "required title validation honors loaded attributes and PostgreSQL NOT NULL" do
    OperatorIdentityState.ensure_defaults!
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "agent-projected-title-#{SecureRandom.hex(8)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(2**62),
      status_id: OperatorIdentityState::ACTIVE,
    )
    agent = Agent.create!(operator_identity: identity, moniker: "Original", title: "Agent01")

    invalid = agent.dup
    invalid.title = nil

    assert_not invalid.valid?
    assert invalid.errors.of_kind?(:title, :blank)

    assert_raises(ActiveRecord::NotNullViolation) do
      Agent.transaction(requires_new: true) do
        Agent.insert_all!(
          [
            { operator_identity_id: identity.id,
              public_id: PublicId.generate,
              title: nil,
              created_at: Time.current,
              updated_at: Time.current, },
          ],
        )
      end
    end

    projection = Agent.select(*(Agent.column_names - ["title"])).find(agent.id)
    projection.update!(moniker: "Revised")

    assert_equal "Revised", projection.reload.moniker
    assert_equal "Agent01", projection.title
  end
end
