#!/usr/bin/env ruby
# frozen_string_literal: true

# Tests for scripts/lib/risk_lane.rb, against the shapes the apps'
# config/risky_paths.yml files take today: Markaz lists no dependency file
# (risk-low), SFA/Garden/Harvest list Gemfile, Gemfile.lock, package.json and
# yarn.lock (risk-high), Optimus has no file (no label). Run via:
#
#   ruby scripts/test/risk_lane_test.rb

require "tmpdir"
require "open3"

LIB = File.expand_path("../lib/risk_lane.rb", __dir__)

CONFIG_WITHOUT_DEPENDENCIES = <<~YAML
  paths:
    deploy_and_infrastructure:
      reason: These ship to production servers.
      globs:
        - .github/workflows/**/*
        - config/deploy*.yml
  kinds:
    - new_dependency: Any gem, package or vendor the app does not use today.
YAML

CONFIG_WITH_DEPENDENCIES = <<~YAML
  paths:
    dependencies:
      reason: Every gem and package ships to production.
      globs:
        - Gemfile
        - Gemfile.lock
        - package.json
        - yarn.lock
        - app/themes/*/package.json
  kinds:
    - new_dependency: Any gem, package or vendor the app does not use today.
YAML

@failures = []

def assert_equal(expected, actual, label)
  if expected == actual
    puts "  PASS #{label}"
  else
    @failures << label
    puts "  FAIL #{label}"
    puts "    expected: #{expected.inspect}"
    puts "    actual:   #{actual.inspect}"
  end
end

# Changed files go on stdin; the block, if given, returns the new package names.
def lane(config, *files)
  new_packages = block_given? ? yield : []
  Open3.capture3(RbConfig.ruby, LIB, config, *new_packages, stdin_data: files.map { |f| "#{f}\0" }.join)
end

Dir.mktmpdir do |dir|
  without = File.join(dir, "without.yml")
  with = File.join(dir, "with.yml")
  File.write(without, CONFIG_WITHOUT_DEPENDENCIES)
  File.write(with, CONFIG_WITH_DEPENDENCIES)

  puts "dependency files not listed -> risk-low"
  stdout, _, status = lane(without, "Gemfile", "Gemfile.lock")
  assert_equal(true, status.success?, "exits 0")
  assert_equal("risk-low\n", stdout, "gem files label")
  stdout, = lane(without, "package.json", "yarn.lock", ".yarn/install-state.gz")
  assert_equal("risk-low\n", stdout, "package files label")

  puts "dependency files listed -> risk-high"
  stdout, stderr, = lane(with, "Gemfile", "Gemfile.lock")
  assert_equal("risk-high\n", stdout, "gem files label")
  assert_equal(true, stderr.include?("Gemfile.lock (dependencies: Gemfile.lock)"), "names the matching file and glob")
  stdout, = lane(with, "yarn.lock")
  assert_equal("risk-high\n", stdout, "one listed file is enough")
  stdout, = lane(with, ".yarnrc.yml")
  assert_equal("risk-low\n", stdout, "unlisted file stays low")

  puts "FNM_PATHNAME and FNM_DOTMATCH match the apps' matcher"
  stdout, = lane(without, ".github/workflows/ci.yml")
  assert_equal("risk-high\n", stdout, "** crosses directories and matches dotfiles")
  stdout, = lane(with, "app/themes/a/b/package.json")
  assert_equal("risk-low\n", stdout, "* does not cross a directory")

  puts "a package new to the lockfile -> risk-high (new_dependency)"
  stdout, stderr, = lane(without, "Gemfile.lock") { ["nokogiri"] }
  assert_equal("risk-high\n", stdout, "new package with unlisted files")
  assert_equal(true, stderr.include?("new_dependency") && stderr.include?("nokogiri"), "names the new package")
  stdout, = lane(without, "Gemfile.lock") { [""] }
  assert_equal("risk-low\n", stdout, "empty name (no new packages) stays low")
  stdout, = lane(File.join(dir, "missing.yml"), "Gemfile.lock") { ["nokogiri"] }
  assert_equal("", stdout, "no config still prints nothing")

  puts "no config/risky_paths.yml -> no label"
  stdout, _, status = lane(File.join(dir, "missing.yml"), "Gemfile")
  assert_equal(true, status.success?, "exits 0")
  assert_equal("", stdout, "prints nothing")

  puts "bad input fails"
  _, _, status = lane(with)
  assert_equal(false, status.success?, "no changed files exits non-zero")
  File.write(File.join(dir, "empty.yml"), "kinds: []\n")
  _, _, status = lane(File.join(dir, "empty.yml"), "Gemfile")
  assert_equal(false, status.success?, "config without paths exits non-zero")
end

if @failures.empty?
  puts "\nAll risk_lane tests passed."
else
  puts "\n#{@failures.length} failure(s): #{@failures.join(', ')}"
  exit 1
end
