# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientExternalIdentityUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "unreleased encrypted subject is unique per issuer across owners and preserves SQL enforcement" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    identity = ClientExternalIdentity.create!(
      client: owner, provider: "google", issuer: "https://accounts.google.com", subject: "contract-subject",
      audience: "contract-client", verification_authority: "verified-ceremony", verified_at: Client.database_now,
    )
    duplicate = ClientExternalIdentity.new(
      client: other, provider: "google", issuer: identity.issuer, subject: identity.subject,
      audience: "contract-client", verification_authority: "verified-ceremony", verified_at: Client.database_now,
    )

    assert_predicate duplicate, :invalid?
    assert duplicate.errors.of_kind?(:subject, :taken)
    assert_not duplicate.errors.include?(:client_id)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientExternalIdentity.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    duplicate.issuer = "https://appleid.apple.com"
    duplicate.provider = "apple"

    assert_predicate duplicate, :valid?
    duplicate.save!

    assert_equal duplicate.id, ClientExternalIdentity.find_by!(issuer: duplicate.issuer, subject: identity.subject).id
    ciphertext = ClientExternalIdentity.connection.select_value(
      ClientExternalIdentity.where(id: duplicate.id).select(:subject).to_sql,
    )

    assert_not_equal identity.subject, ciphertext
  end

  test "release makes both keys available while released history remains unconstrained" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    attributes = {
      client: owner,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "released-subject",
      audience: "contract-client",
      verification_authority: "verified-ceremony",
      verified_at: Client.database_now,
    }
    original = ClientExternalIdentity.create!(attributes)
    original.release!
    replacement = ClientExternalIdentity.create!(attributes)
    historical = ClientExternalIdentity.new(
      attributes.merge(
        released_at: Client.database_now,
        state: "consent_revoked",
      ),
    )

    assert_predicate historical, :valid?
    historical.save!

    assert_equal 1, ClientExternalIdentity.effective_binding.where(client_id: owner.id).count
    assert_not_predicate original.reload, :active?
    assert_predicate replacement, :active?
    assert_raises(ActiveRecord::RecordInvalid) { original.update!(released_at: nil, state: "active") }
    assert original.errors.of_kind?(:client_id, :taken)
    assert original.errors.of_kind?(:subject, :taken)
    assert_raises(ActiveRecord::StatementInvalid) do
      ClientExternalIdentity.transaction(requires_new: true) do
        ClientExternalIdentity.where(id: original.id).update_all(released_at: nil)
      end
    end
    assert original.reload.released_at
  end

  test "unreleased nonactive states retain their reserved client and subject keys" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    original = ClientExternalIdentity.create!(
      client: owner, provider: "google", issuer: "https://accounts.google.com", subject: "nonactive-subject",
      audience: "contract-client", verification_authority: "verified-ceremony", verified_at: Client.database_now,
      state: "consent_revoked",
    )
    duplicate = original.dup
    duplicate.state = "account_deleted"

    assert_predicate duplicate, :invalid?
    assert duplicate.errors.of_kind?(:client_id, :taken)
    assert duplicate.errors.of_kind?(:subject, :taken)
    assert_nil original.released_at
  end

  test "unchanged authentication metadata and release do not add uniqueness probes" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    identity = ClientExternalIdentity.create!(
      client: owner, provider: "google", issuer: "https://accounts.google.com", subject: "probe-subject",
      audience: "contract-client", verification_authority: "verified-ceremony", verified_at: Client.database_now,
    )
    probes = []
    probe = /SELECT.*FROM .*client_external_identities/i
    subscriber = ->(_name, _start, _finish, _id, payload) { probes << true if payload[:sql].match?(probe) }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      identity.touch_authenticated!
      identity.release!
    end

    assert_empty probes
    assert identity.reload.released_at
  end
end

class ClientExternalIdentityUniquenessConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "PostgreSQL resolves concurrent writes after both unreleased bindings pass preflight" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    ready = Queue.new
    start = Queue.new
    workers =
      2.times.map do
        Thread.new do
          ClientExternalIdentity.connection_pool.with_connection do
            candidate = ClientExternalIdentity.new(
              client_id: owner.id, provider: "google", issuer: "https://accounts.google.com",
              subject: "race-contract-subject", audience: "contract-client",
              verification_authority: "verified-ceremony", verified_at: Client.database_now,
            )
            ready << candidate.valid?
            start.pop
            begin
              ClientExternalIdentity.transaction { candidate.save!(validate: false) }
              :saved
            rescue ActiveRecord::RecordNotUnique
              :duplicate
            end
          end
        end
      end
    preflight = 2.times.map { Timeout.timeout(10) { ready.pop } }
    2.times { start << true }
    results = workers.map(&:value)

    assert_equal [true, true], preflight
    assert_equal 1, results.count(:saved)
    assert_equal 1, results.count(:duplicate)
    assert_equal 1, ClientExternalIdentity.effective_binding.where(client_id: owner.id).count
  ensure
    2.times { start << true } if start
    workers&.each(&:join)
    if owner
      ClientExternalIdentity.where(client_id: owner.id).delete_all
      Client.where(id: owner.id).delete_all
    end
  end
end
