require "test_helper"

class AssetPolicyTest < ActiveSupport::TestCase
  test "for resolves the per-type policy" do
    assert_instance_of VendorPolicy, AssetPolicy.for(users(:owner), vendors(:acme))
    assert_instance_of SystemPolicy, AssetPolicy.for(users(:owner), systems(:tracker))
  end

  test "compliance edits every field directly" do
    policy = AssetPolicy.for(users(:compliance), vendors(:acme))
    assert policy.editable_directly?(:name)
    assert policy.editable_directly?(:risk_tier)
    assert policy.editable_directly?(:status)
    assert policy.may_manage_delegates?
  end

  test "owner edits regular fields but no compliance fields" do
    policy = AssetPolicy.for(users(:owner), vendors(:acme))
    assert policy.editable_directly?(:name)
    assert policy.editable_directly?(:owner_id)
    assert policy.editable_directly?(:status)
    assert_not policy.editable_directly?(:risk_tier)
    assert_not policy.editable_directly?(:processes_personal_data)
    assert policy.may_manage_delegates?
  end

  test "delegate has the same direct powers as the owner" do
    policy = AssetPolicy.for(users(:delegate), systems(:tracker))
    assert policy.editable_directly?(:description)
    assert_not policy.editable_directly?(:criticality)
    assert policy.may_manage_delegates?
  end

  test "nobody but compliance touches the status of a pending asset" do
    pending = vendors(:pending_vendor)
    assert_not AssetPolicy.for(users(:employee), pending).editable_directly?(:status)
    assert AssetPolicy.for(users(:compliance), pending).editable_directly?(:status)
  end

  test "admin can only repair ownership" do
    policy = AssetPolicy.for(users(:admin), vendors(:acme))
    assert policy.editable_directly?(:owner_id)
    assert policy.may_manage_delegates?
    assert_not policy.editable_directly?(:name)
    assert_not policy.editable_directly?(:risk_tier)
  end

  test "unrelated member edits nothing directly" do
    policy = AssetPolicy.for(users(:employee), vendors(:acme))
    assert_not policy.editable_directly?(:name)
    assert_not policy.may_edit_anything?
    assert_not policy.may_manage_delegates?
    assert_empty policy.editable_fields
  end
end
