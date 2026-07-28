require "test_helper"

class Demo::VolumeSeederTest < ActiveSupport::TestCase
  SCALE = 40

  test "does nothing at the default scale of 0" do
    assert_no_difference [ "Vendor.count", "System.count", "AuditEvent.count", "User.count" ] do
      Demo::VolumeSeeder.call(scale: 0)
    end
  end

  test "seed! stays at scale 0 unless DEMO_VOLUME says otherwise" do
    assert_equal 0, Demo::Seeder.volume_scale

    ENV["DEMO_VOLUME"] = "25"
    assert_equal 25, Demo::Seeder.volume_scale
    ENV["DEMO_VOLUME"] = "not-a-number"
    assert_equal 0, Demo::Seeder.volume_scale, "a bad value must not blow up the seed"
  ensure
    ENV.delete("DEMO_VOLUME")
  end

  test "lays volume on top without disturbing the curated records" do
    Demo::Seeder.reset!
    curated = Vendor.order(:name).pluck(:name, :risk_tier)

    assert_difference "Vendor.count", SCALE do
      Demo::VolumeSeeder.call(scale: SCALE)
    end

    assert_equal curated, Vendor.where(name: curated.map(&:first)).order(:name).pluck(:name, :risk_tier)
    assert Vendor.exists?(name: "Acme Cloud"), "the docs walk through this record by name"
  end

  test "populates every filter dimension the tables expose" do
    Demo::Seeder.reset!
    Demo::VolumeSeeder.call(scale: SCALE)
    user = User.first

    %w[overdue due_soon never ok].each do |bucket|
      assert_operator table(VendorTable, user, "review_status" => bucket).count, :>, 0,
                      "review-status bucket #{bucket} is empty"
    end
    Vendor::RISK_TIERS.each do |tier|
      assert_operator table(VendorTable, user, "risk_tier" => tier).count, :>, 0, "no #{tier}-tier vendors"
    end
    System::CRITICALITIES.each do |level|
      assert_operator table(SystemTable, user, "criticality" => level).count, :>, 0, "no #{level}-criticality systems"
    end

    # "Not recorded" is a real state — an unscored vendor, an unclassified system.
    assert Vendor.where(risk_tier: nil).exists?
    assert System.where(criticality: nil).exists?
    # In-house systems, for the blank branch of the vendor filter and the join sort.
    assert System.where(vendor_id: nil).exists?
    # The ⚖ booleans are three-state.
    assert_equal [ nil, false, true ], Vendor.distinct.pluck(:processes_personal_data).sort_by(&:to_s)
  end

  # Correlated fields were a real bug here: indexing every enum by the row number
  # made criticality and data classification advance in lockstep, so combining
  # two filters returned almost nothing.
  test "enum fields are independent, so combined filters still match rows" do
    Demo::Seeder.reset!
    Demo::VolumeSeeder.call(scale: 300)
    user = User.first

    combinations = System::CRITICALITIES.product(System::DATA_CLASSIFICATIONS)
    empty = combinations.reject do |criticality, classification|
      table(SystemTable, user, "criticality" => criticality, "data_classification" => classification).count.positive?
    end

    assert_empty empty, "these criticality/classification combinations matched nothing: #{empty.inspect}"
  end

  test "the same seed produces the same sandbox" do
    assert_equal fresh_volume, fresh_volume
  end

  test "a second run tops up instead of colliding on unique names" do
    Demo::Seeder.reset!
    Demo::VolumeSeeder.call(scale: SCALE)

    assert_difference "Vendor.count", SCALE do
      Demo::VolumeSeeder.call(scale: SCALE)
    end
  end

  private

  def table(klass, user, params)
    klass.new(user: user, params: ActionController::Parameters.new(params).permit!).scope
  end

  def fresh_volume
    Demo::Seeder.reset!
    Demo::VolumeSeeder.call(scale: 15, seed: 99)
    Vendor.order(:name).pluck(:name, :risk_tier, :status, :data_location)
  end
end
