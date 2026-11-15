# frozen_string_literal: true

require "test_helper"

class ClientPersonaTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientPersona)
  end

  test "required title validation honors loaded attributes and PostgreSQL NOT NULL" do
    ClientIdentityState.ensure_defaults!
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "persona-projected-title-#{SecureRandom.hex(8)}",
      audience: "acme_app",
      source_record_id: SecureRandom.random_number(2**62),
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = ClientPersona.create!(client_identity: identity, moniker: "Original", title: "Persona1")

    invalid = persona.dup
    invalid.title = nil

    assert_not invalid.valid?
    assert invalid.errors.of_kind?(:title, :blank)

    assert_raises(ActiveRecord::NotNullViolation) do
      ClientPersona.transaction(requires_new: true) do
        ClientPersona.insert_all!(
          [
            { client_identity_id: identity.id,
              public_id: PublicId.generate,
              title: nil,
              created_at: Time.current,
              updated_at: Time.current, },
          ],
        )
      end
    end

    projection = ClientPersona.select(*(ClientPersona.column_names - ["title"])).find(persona.id)
    projection.update!(moniker: "Revised")

    assert_equal "Revised", projection.reload.moniker
    assert_equal "Persona1", projection.title
  end
end
