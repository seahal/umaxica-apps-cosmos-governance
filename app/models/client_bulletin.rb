# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_bulletins
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  body       :text
#  read_at    :datetime
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_bulletins_on_public_id  (public_id) UNIQUE
#  index_client_bulletins_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#
class ClientBulletin < AppPrincipalRecord
  include PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  belongs_to :user, class_name: "Client", inverse_of: :client_bulletins

  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :oldest_first, -> { order(created_at: :asc) }

  public
  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end
end
