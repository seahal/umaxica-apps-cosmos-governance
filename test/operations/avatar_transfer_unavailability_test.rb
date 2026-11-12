# frozen_string_literal: true

require "test_helper"

class AvatarTransferUnavailabilityTest < ActiveSupport::TestCase
  ["app", "org"].each do |surface|
    [nil, "untrusted-proof"].each do |proof|
      test "#{surface} transfer requests refuse missing authority with #{proof.inspect} before ownership writes" do
        snapshot = ownership_snapshot
        actor = (surface == "app") ? clients(:one) : operators(:one)
        common = {
          actor:,
          surface:,
          subject_public_id: "untrusted-subject",
          avatar_public_id: "untrusted-avatar",
          target_surface: (surface == "app") ? "org" : "app",
          target_collective_public_id: "untrusted-owner",
          step_up_token: proof,
          step_up_evidence: proof,
        }
        assert_raises(AccessOpDataUnavailableError) { AvatarOwnershipTransfers::RequestOperation.call(**common) }
        assert_raises(AccessOpDataUnavailableError) do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            **common, idempotency_key: SecureRandom.uuid, request_fingerprint: "untrusted-fingerprint",
          )
        end
        assert_equal snapshot, ownership_snapshot
      end
    end

    [AvatarOwnershipTransfers::AcceptOperation, AvatarOwnershipTransfers::CancelOperation,
     AvatarOwnershipTransfers::RegistryAcceptOperation,
     AvatarOwnershipTransfers::RegistryCancelOperation,].each do |operation|
      test "#{surface} #{operation.name} refuses missing authority before history or ownership writes" do
        snapshot = ownership_snapshot
        actor = (surface == "app") ? clients(:one) : operators(:one)
        reference = operation.name.include?("Registry") ? :reservation_public_id : :transfer_public_id
        assert_raises(AccessOpDataUnavailableError) do
          operation.call(
            :actor => actor, :surface => surface, :subject_public_id => "untrusted-subject",
            reference => "untrusted-transfer",
          )
        end
        assert_equal snapshot, ownership_snapshot
      end
    end
  end

  private

  def ownership_snapshot
    [Avatar, AvatarOwnershipTransfer, AvatarEnterpriseOwnershipPeriod, AvatarBureauOwnershipPeriod,
     AvatarTransferReservation,].map { |model| model.order(:id).map(&:attributes) }
  end
end
