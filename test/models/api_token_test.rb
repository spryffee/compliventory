require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "generate_raw_token carries the prefix and enough entropy" do
    raw = ApiToken.generate_raw_token
    assert raw.start_with?(ApiToken::PREFIX)
    assert_operator raw.length, :>=, 40
  end

  test "find_by_raw_token round-trips a generated token" do
    raw = ApiToken.generate_raw_token
    token = ApiToken.create!(name: "T", token_digest: ApiToken.digest(raw))
    assert_equal token, ApiToken.find_by_raw_token(raw)
  end

  test "find_by_raw_token rejects values without the prefix" do
    raw = ApiToken.generate_raw_token
    ApiToken.create!(name: "T", token_digest: ApiToken.digest(raw))
    assert_nil ApiToken.find_by_raw_token(raw.delete_prefix(ApiToken::PREFIX))
    assert_nil ApiToken.find_by_raw_token(nil)
  end

  test "expiry gates redeemability" do
    assert api_tokens(:sync).redeemable?
    assert_not api_tokens(:expired).redeemable?
  end

  test "scope must be known" do
    token = ApiToken.new(name: "T", token_digest: "x", scope: "everything")
    assert_not token.valid?
  end
end
