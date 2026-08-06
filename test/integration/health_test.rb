require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "answers 200 to anyone, signed in or not" do
    get "/up"
    assert_response :ok
  end

  test "answers 503 when the database does not" do
    with_unreachable_database do
      get "/up"
      assert_response :service_unavailable
    end
  end

  private

  # Minitest 6 ships no mocking library, and reconnecting to a bogus database for
  # real would take the fixtures' transaction with it — so the accessor is
  # swapped by hand. Safe under parallel tests: each worker is its own process
  # and its tests run one at a time.
  def with_unreachable_database
    singleton = ActiveRecord::Base.singleton_class
    singleton.alias_method :connection_before_probe, :connection
    singleton.define_method(:connection) { raise ActiveRecord::ConnectionNotEstablished }
    yield
  ensure
    singleton.alias_method :connection, :connection_before_probe
    singleton.remove_method :connection_before_probe
  end
end
