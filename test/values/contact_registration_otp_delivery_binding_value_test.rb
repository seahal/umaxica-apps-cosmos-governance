# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "Telephone registration accepts exact five-field APP and opaque ORG bindings" do
    %w(app org).each do |surface|
      tuple = [surface, "credential_registration", "12345678-1234-4000-8000-123456789abc",
               (surface == "org") ? "OrgContact_1234567890" : "Contact_1-", "87654321-4321-4000-b000-cba987654321",]
      value = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)

      assert_equal surface, value.surface
      assert_equal tuple[1], value.purpose
      assert_equal tuple[2], value.transaction_ref
      assert_equal tuple[3], value.candidate_ref
      assert_equal tuple[4], value.generation
      assert_equal tuple, value.to_a
      [tuple.take(4), tuple + ["extra"]].each do |invalid|
        assert_raises(ArgumentError) {
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: invalid)
        }
      end
    end
  end

  test "Telephone binding rejects missing empty and non-array tuple sentinels" do
    [nil, [], {}, "tuple", 0, false].each do |invalid|
      assert_raises(ArgumentError) {
        TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: invalid)
      }
    end
    assert_raises(ArgumentError) { TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms }
  end

  test "Telephone surface and purpose require canonical scalar strings and ORG requires opaque candidate ownership" do
    { 0 => [nil, "", "dev", "com", "visitor", "APP", :app, [], {}, 0, false],
      1 => [nil, "", "sign_up", "sign_in", :credential_registration, [], {}, 0, false], }.each do |index, invalids|
      invalids.each do |invalid|
        tuple = %w(app credential_registration 12345678-1234-4000-8000-123456789abc contact
                   87654321-4321-4000-b000-cba987654321)
        tuple[index] = invalid
        assert_raises(ArgumentError) {
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
        }
      end
    end
    ["a" * 21, "A_-" + ("9" * 18)].each do |candidate|
      tuple = ["org", "credential_registration", "12345678-1234-4000-8000-123456789abc",
               candidate, "87654321-4321-4000-b000-cba987654321",]

      assert_equal candidate,
                   TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple).candidate_ref
    end
    [nil, "", "0", "1", "01", "-1", "+1", "contact", "a" * 20, "a" * 22, ("a" * 20) + "\0"].each do |candidate|
      assert_raises(ArgumentError) do
        TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: ["org", "credential_registration", "12345678-1234-4000-8000-123456789abc",
                        candidate, "87654321-4321-4000-b000-cba987654321",],
        )
      end
    end
  end

  test "Telephone transaction reference accepts UUID or NanoID while generation remains a UUID" do
    uuid = "12345678-1234-4000-8000-123456789abc"
    %w(8 9 a b).each do |variant|
      reference = uuid.sub("-8000-", "-#{variant}000-")
      value = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
        otp_binding: ["app", "credential_registration", reference, "contact", uuid],
      )

      assert_equal reference, value.transaction_ref
      assert_equal uuid, value.generation
    end
    nanoid = "A1_b2-C3d4E5f6G7h8I9j"
    value = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
      otp_binding: ["app", "credential_registration", nanoid, "contact", uuid],
    )

    assert_equal nanoid, value.transaction_ref
    [nil, "", " ", "transaction", uuid[0...35], uuid + "0", uuid.upcase,
     uuid.sub("-4000-", "-3000-"), uuid.sub("-4000-", "-5000-"),
     uuid.sub("-8000-", "-7000-"), uuid.sub("-8000-", "-c000-"),
     uuid.sub("-8000-", "-0000-"), uuid.sub("9abc", "9abg"), uuid.delete("-"),
     uuid + "\n", "\xFF", uuid.encode("UTF-16LE"), [], {}, 0, false,].each do |invalid|
      [2, 4].each do |index|
        tuple = ["app", "credential_registration", uuid, "contact", uuid]
        tuple[index] = invalid
        assert_raises(ArgumentError) do
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
        end
      end
    end
  end

  test "APP candidate references retain one through twenty-one character boundaries" do
    %w(app).each do |surface|
      ["a", "aa", "a" * 20, "a" * 21].each do |reference|
        value = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: [surface, "credential_registration", "12345678-1234-4000-8000-123456789abc",
                        reference, "87654321-4321-4000-b000-cba987654321",],
        )

        assert_equal reference, value.candidate_ref
      end
      [nil, "", "a" * 22, " ", "a b", "a/b", "a.b", "a\n", "é", "電話", "\xFF",
       "a".encode("UTF-16LE"), [], {}, 0, false,].each do |invalid|
        assert_raises(ArgumentError) do
          TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
            otp_binding: [surface, "credential_registration", "12345678-1234-4000-8000-123456789abc",
                          invalid, "87654321-4321-4000-b000-cba987654321",],
          )
        end
      end
    end
  end

  test "opaque UUID generation rejects every former decimal counter partition without counter arithmetic" do
    # Decimal counter bounds are superseded, not UUID arithmetic boundaries.
    ["0", "1", ((1 << 64) - 2).to_s, ((1 << 64) - 1).to_s,
     nil, "", "-1", (1 << 64).to_s, "00", "01", "+1", " 1", "1 ", "1\n", "1.0", "1e1", "０",
     0, 1, [], {}, false,].each do |invalid|
      assert_raises(ArgumentError) do
        TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(
          otp_binding: ["app", "credential_registration", "12345678-1234-4000-8000-123456789abc", "contact", invalid],
        )
      end
    end
  end

  test "Telephone binding owns an immutable snapshot despite caller strings and exported container mutation" do
    tuple = [+"app", +"credential_registration", +"12345678-1234-4000-8000-123456789abc",
             +"contact", +"87654321-4321-4000-b000-cba987654321",]
    expected = tuple.map(&:dup)
    telephone = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: tuple)
    tuple.each { |field| field.replace("changed") }
    exported = telephone.to_a
    exported[0] = "changed"

    assert_predicate telephone, :frozen?
    assert_equal expected, telephone.to_a
    [
      telephone.surface, telephone.purpose, telephone.transaction_ref, telephone.candidate_ref, telephone.generation,
    ].each do |field|
      assert_raises(FrozenError) { field.replace("changed") }
    end
  end
end
