# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierBlindIndexTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "blank identifiers have no lookup digest" do
    %w(app org).each do |realm|
      [nil, "", "   "].each do |identifier|
        assert_nil IdentifierBlindIndex.bidx_for_email(identifier, realm: realm)
        assert_nil IdentifierBlindIndex.bidx_for_telephone(identifier, realm: realm)
      end
    end
  end

  %w(app org).each do |realm|
    %w(email telephone).each do |channel|
      test "#{realm} #{channel} uses its encrypted credential even when ENV disagrees" do
        key_name =
          case channel
          when "email" then "#{realm.upcase}_EMAIL_ADDRESS_HMAC_KEY"
          when "telephone" then "#{realm.upcase}_TELEPHONE_NUMBER_HMAC_KEY"
          end
        original = ENV[key_name]
        ENV[key_name] = "synthetic-env-key-must-not-be-used"
        configured = ->(key) { "synthetic-credential-key" if key == key_name.to_sym }
        Rails.app.credentials.stub(:option, configured) do
          case channel
          when "email"
            expected = OpenSSL::HMAC.hexdigest(
              "SHA256", "synthetic-credential-key", "#{realm}:email:user@example.com",
            )

            assert_equal expected, IdentifierBlindIndex.bidx_for_email(" USER@Example.COM ", realm: realm)
          when "telephone"
            expected = OpenSSL::HMAC.hexdigest(
              "SHA256", "synthetic-credential-key", "#{realm}:telephone:+819012345678",
            )

            assert_equal expected, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: realm)
          end
        end
      ensure
        if original.nil?
          ENV.delete(key_name)
        else
          ENV[key_name] = original
        end
      end

      [nil, "", "   "].each do |missing|
        test "#{realm} #{channel} refuses #{missing.inspect} credentials even when ENV has a key" do
          key_name =
            case channel
            when "email" then "#{realm.upcase}_EMAIL_ADDRESS_HMAC_KEY"
            when "telephone" then "#{realm.upcase}_TELEPHONE_NUMBER_HMAC_KEY"
            end
          original = ENV[key_name]
          ENV[key_name] = "synthetic-env-key-must-not-be-used"
          Rails.app.credentials.stub(:option, missing) do
            error =
              assert_raises(KeyError) do
                case channel
                when "email" then IdentifierBlindIndex.bidx_for_email("user@example.com", realm: realm)
                when "telephone" then IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: realm)
                end
              end

            assert_equal "Missing key: [:#{key_name}]", error.message
          end
        ensure
          if original.nil?
            ENV.delete(key_name)
          else
            ENV[key_name] = original
          end
        end
      end
    end
  end
end
