# frozen_string_literal: true

require "test_helper"

class EnterpriseTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::Enterprise)
  end

  test "required name and title remain valid for complete and projected records" do
    enterprise = Enterprise.create!(name: "Original", title: "Original")

    invalid_name = enterprise.dup
    invalid_name.name = nil

    assert_not invalid_name.valid?
    assert invalid_name.errors.of_kind?(:name, :blank)

    invalid_title = enterprise.dup
    invalid_title.title = nil

    assert_not invalid_title.valid?
    assert invalid_title.errors.of_kind?(:title, :blank)

    assert_raises(ActiveRecord::NotNullViolation) do
      Enterprise.transaction(requires_new: true) do
        Enterprise.insert_all!(
          [
            { public_id: PublicId.generate,
              name: nil,
              title: "Valid",
              created_at: Time.current,
              updated_at: Time.current, },
          ],
        )
      end
    end
    assert_raises(ActiveRecord::NotNullViolation) do
      Enterprise.transaction(requires_new: true) do
        Enterprise.insert_all!(
          [
            { public_id: PublicId.generate,
              name: "Valid",
              title: nil,
              created_at: Time.current,
              updated_at: Time.current, },
          ],
        )
      end
    end

    projected_without_name = Enterprise.select(*(Enterprise.column_names - ["name"])).find(enterprise.id)
    projected_without_name.update!(title: "Revised")

    assert_equal "Original", projected_without_name.reload.name

    projected_without_title = Enterprise.select(*(Enterprise.column_names - ["title"])).find(enterprise.id)
    projected_without_title.update!(name: "Revised")

    assert_equal "Revised", projected_without_title.reload.name
    assert_equal "Revised", projected_without_title.title
  end
end
