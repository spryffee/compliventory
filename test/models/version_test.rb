require "test_helper"

class VersionTest < ActiveSupport::TestCase
  # The VERSION file is the single source of truth: the release workflow bumps
  # it, the image label copies it, and /admin renders it. A malformed value
  # would produce nonsense image tags, so fail here instead.
  test "the version is semver" do
    assert_match(/\A\d+\.\d+\.\d+\z/, Compliventory::VERSION,
                 "VERSION must be MAJOR.MINOR.PATCH, got #{Compliventory::VERSION.inspect}")
  end

  test "the constant matches the VERSION file" do
    assert_equal Rails.root.join("VERSION").read.strip, Compliventory::VERSION
  end
end
