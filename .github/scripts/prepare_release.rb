#!/usr/bin/env ruby
# frozen_string_literal: true

# Prepares a release, driven by .github/workflows/release.yml:
#
#   1. bumps VERSION by patch / minor / major
#   2. turns the CHANGELOG's "Unreleased" section into a dated one for the new
#      version, appending the commit subjects since the last tag
#   3. writes the GitHub Release body to the path given as the second argument
#
# Prints `key=value` lines for GITHUB_OUTPUT. Touches no git state — the
# workflow commits, tags and pushes, so a failed image build leaves nothing
# behind.
#
#   ruby .github/scripts/prepare_release.rb patch /tmp/notes.md

bump = ARGV.fetch(0)
notes_path = ARGV.fetch(1)

root = File.expand_path("../..", __dir__)
version_file = File.join(root, "VERSION")
changelog_file = File.join(root, "CHANGELOG.md")

major, minor, patch = File.read(version_file).strip.split(".").map(&:to_i)
case bump
when "major" then major, minor, patch = major + 1, 0, 0
when "minor" then minor, patch = minor + 1, 0
when "patch" then patch += 1
else abort "unknown bump #{bump.inspect} — expected patch, minor or major"
end
version = [ major, minor, patch ].join(".")

# What shipped: hand-written upgrade notes first (someone thought about them
# while making the change), then the raw commit list so nothing is invisible.
last_tag = `git describe --tags --abbrev=0 2>/dev/null`.strip # no tags yet on a first release
range = $?.success? && !last_tag.empty? ? "#{last_tag}..HEAD" : ""
commits = `git log --no-merges --pretty=format:"- %s" #{range}`.strip

changelog = File.read(changelog_file)
unreleased_section = /^## Unreleased\n.*?(?=^## |\z)/m
written = changelog[unreleased_section].to_s
              .sub(/^## Unreleased\n/, "")
              .gsub(/<!--.*?-->/m, "") # drop the how-to-use comment
              .strip

body = [ written, commits.empty? ? nil : "### Commits\n\n#{commits}" ]
       .compact.reject(&:empty?).join("\n\n")
body = "No changes recorded." if body.empty?

entry = "## #{version} — #{Time.now.strftime('%Y-%m-%d')}\n\n#{body}\n"
# Block form: commit subjects may contain backslash sequences that the string
# form of sub would read as backreferences.
changelog = changelog.sub(unreleased_section) { "## Unreleased\n\n#{entry}\n" }

File.write(version_file, "#{version}\n")
File.write(changelog_file, changelog)
File.write(notes_path, "#{body}\n")

puts "version=#{version}"
puts "major=#{major}"
puts "major_minor=#{major}.#{minor}"
