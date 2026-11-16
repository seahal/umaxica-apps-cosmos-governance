# frozen_string_literal: true

# Historical source fact. Current account/credential status never substitutes for this receipt.
class ClientRegistrationCompletion < AppZenithRecord
  belongs_to :client, inverse_of: :registration_completions
  belongs_to :completion_method, foreign_key: :method_id, class_name: "ClientRegistrationCompletionMethod",
                                 inverse_of: :completions
  validates :client_id, :public_id, :sign_up_flow_ref, uniqueness: true, on: :create
  validates :public_id, :sign_up_flow_ref, presence: true
  validates :public_id, :sign_up_flow_ref, length: { is: 21 }
  validates :completed_at, presence: true

  public

  def readonly?
    persisted?
  end
end
