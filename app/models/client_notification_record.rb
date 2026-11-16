# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_notification_records
# Database name: app_signal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_notification_records_on_public_id  (public_id) UNIQUE
#  index_client_notification_records_on_user_id    (user_id)
#

class ClientNotificationRecord < AppSignalRecord
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  belongs_to :client,
             class_name: "Client",
             foreign_key: :user_id,
             inverse_of: :notification_records
  has_many :member_notifications,
           foreign_key: :user_notification_id,
           inverse_of: :client_notification_record,
           dependent: :delete_all
end
