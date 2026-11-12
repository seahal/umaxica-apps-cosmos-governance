# frozen_string_literal: true

class ValidateRetainedAvatarConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:avatar_enterprise_to_bureau_transfer_details, name: "fk_rails_1452263e0a")
    validate_foreign_key(:avatar_mutes, name: "fk_rails_23710bcc08")
    validate_foreign_key(:avatar_bureau_to_enterprise_transfer_details, name: "fk_rails_4dfe4d6053")
    validate_foreign_key(:avatar_bureau_to_bureau_transfer_details, name: "fk_rails_71685bc7cf")
    validate_foreign_key(:avatar_blocks, name: "fk_rails_8250386a91")
    validate_foreign_key(:avatar_blocks, name: "fk_rails_903ed2c4c2")
    validate_foreign_key(:avatar_enterprise_to_enterprise_transfer_details, name: "fk_rails_bf9c472635")
    validate_foreign_key(:avatar_mutes, name: "fk_rails_c0a7894e9b")
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Keep existing constraints validated when rolling application code back"
  end
end
