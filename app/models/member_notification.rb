# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: member_notifications
# Database name: app_signal
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  public_id            :string           default(""), not null
#  user_notification_id :bigint           not null
#
# Indexes
#
#  index_member_notifications_on_public_id             (public_id) UNIQUE
#  index_member_notifications_on_user_notification_id  (user_notification_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_notification_id => client_notification_records.id) ON DELETE => cascade
#

class MemberNotification < AppSignalRecord
  include ::PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  belongs_to :client_notification_record,
             class_name: "ClientNotificationRecord",
             foreign_key: :user_notification_id,
             optional: false,
             inverse_of: :member_notifications
end
