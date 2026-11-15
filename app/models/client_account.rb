# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_accounts
# Database name: app_zenith
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_accounts_on_public_id  (public_id) UNIQUE
#  index_client_accounts_on_user_id    (user_id) UNIQUE
#
class ClientAccount < AppRpRecord
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  belongs_to :user, class_name: "Client", inverse_of: :rp_account

  validates :user_id, uniqueness: true
end
