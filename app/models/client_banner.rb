# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_banners
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_banners_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#
class ClientBanner < AppPrincipalRecord
  include BannerModel

  attribute :published, default: false
  attribute :starts_at, default: -> { Time.current }
  attribute :ends_at, default: BannerModel::DISTANT_ENDS_AT

  validates :body, :starts_at, :ends_at, presence: true
  validate :ends_at_after_starts_at

  scope :published, -> { where(published: true) }
  scope :active_now, ->(now = Time.current) { where(starts_at: ..now).where(arel_table[:ends_at].gt(now)) }
  scope :current, ->(now = Time.current) { published.active_now(now).order(starts_at: :desc, id: :desc) }

  belongs_to :user, class_name: "Client", optional: false

  public
  def actor
    user
  end
end
