# frozen_string_literal: true

require "test_helper"

class ClientWithdrawalFlowTest < ActiveSupport::TestCase
  test "withdrawal flow persistence contracts are explicit on its concrete host" do
    source = Rails.root.join("app/models/client_withdrawal_flow.rb").read

    [
      "include ::PublicId",
      "include Retainable",
      "include WithdrawalFlow",
      "include FlowBase",
      "include FlowWithdrawal",
      "def cycle_status_column_name = :status_id",
      "cycle_status_column :status_id",
      "attribute :began_at, :datetime, default: -> { Time.current }",
      "Retainable.register_host(self)",
    ].each do |declaration|
      assert_includes source, declaration
    end
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientWithdrawalFlow)
  end
end
