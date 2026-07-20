require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  setup do
    Current.correlation_id = SecureRandom.uuid
  end

  teardown do
    Current.reset
  end

  test "record! with a user actor captures display and targets snapshot" do
    actor = users(:admin)
    target = users(:employee)

    event = AuditEvent.record!(event_type: "user.role_changed", actor: actor, targets: target)

    assert_equal "user", event.actor_type
    assert_equal actor.id, event.actor_id
    assert_equal actor.name, event.actor_display
    assert_equal [ { "type" => "User", "id" => target.id, "display" => target.name } ], event.targets
    assert_equal target.id, event.target_id("User")
  end

  test "record! with the system actor leaves actor_id blank" do
    event = AuditEvent.record!(event_type: "user.synced", actor: :system, targets: users(:employee))
    assert_equal "system", event.actor_type
    assert_nil event.actor_id
  end

  test "a user-typed event without actor_id is invalid" do
    event = AuditEvent.new(
      occurred_at: Time.current, event_type: "x", actor_type: "user",
      correlation_id: SecureRandom.uuid
    )
    assert_not event.valid?
  end

  test "record! stamps api token attribution into metadata when present" do
    Current.api_token = api_tokens(:sync)
    event = AuditEvent.record!(event_type: "user.synced", actor: :system, targets: users(:employee))
    assert_equal api_tokens(:sync).id, event.metadata["api_token_id"]
    assert_equal "HRIS sync", event.metadata["api_token_name"]
  end
end
