# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_motion_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientPreferenceMotionOption < AppPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  STANDARD = 1
  REDUCED = 2

  DEFAULTS = [NOTHING, STANDARD, REDUCED].freeze

  self.record_timestamps = false

  has_many :client_preference_motions,
           class_name: "ClientPreferenceMotion",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
  public_class_method :ensure_defaults!

  public
  def name
    case id
    when 1 then "standard"
    when 2 then "reduced"
    end
  end
end
