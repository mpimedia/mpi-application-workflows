#!/usr/bin/env ruby
# frozen_string_literal: true

# Fixture tests for scripts/lib/gemfile_edit.rb.
#
# These cover Gemfile shapes the live MPI Gemfiles do not currently contain
# (commented pins, single quotes, multi-requirement pins), so the dry-run
# validation against a real app cannot exercise them. Run via:
#
#   ruby scripts/test/gemfile_edit_test.rb

require "fileutils"
require "tmpdir"
require "open3"

LIB = File.expand_path("../lib/gemfile_edit.rb", __dir__)
FIXTURES = File.expand_path("fixtures", __dir__)

EXPECTED_UNPINNED = <<~GEMFILE
  source "https://rubygems.org", cooldown: 7

  ruby file: ".tool-versions"
  gem "rails"
  gem "pinned_exact"
  gem 'single_quoted'
  gem "with_options", require: false
  gem "commented_pin", "3.1.0" # locked: breaking changes in 4.x
  gem "kamal", require: false
  gem "range_pin"

  group :development, :test do
    gem "grouped_gem"
  end
GEMFILE

# Round trip against an unchanged lockfile: every line is byte-identical
# except the multi-requirement pin, which collapses to one exact pin (MPI
# convention). The live Optimus Gemfile contains only exact pins, so the
# "no updates -> no diff" property holds there.
EXPECTED_REPIN_SAME = <<~GEMFILE
  source "https://rubygems.org", cooldown: 7

  ruby file: ".tool-versions"
  gem "rails", "8.1.3"
  gem "pinned_exact", "1.2.3"
  gem 'single_quoted', '2.0.0'
  gem "with_options", "1.24.5", require: false
  gem "commented_pin", "3.1.0" # locked: breaking changes in 4.x
  gem "kamal", require: false
  gem "range_pin", "1.0.0"

  group :development, :test do
    gem "grouped_gem", "0.9.1"
  end
GEMFILE

EXPECTED_REPIN_UPDATED = <<~GEMFILE
  source "https://rubygems.org", cooldown: 7

  ruby file: ".tool-versions"
  gem "rails", "8.1.4"
  gem "pinned_exact", "1.2.3"
  gem 'single_quoted', '2.1.0'
  gem "with_options", "1.25.0", require: false
  gem "commented_pin", "3.1.0" # locked: breaking changes in 4.x
  gem "kamal", require: false
  gem "range_pin", "1.5.0"

  group :development, :test do
    gem "grouped_gem", "0.10.0"
  end
GEMFILE

EXPECTED_COMMENTS = "commented_pin\t# locked: breaking changes in 4.x\n"

EXPECTED_LOCKDIFF = <<~DIFF
  grouped_gem\t0.9.1\t0.10.0
  kamal\t2.4.0\t2.5.0
  nokogiri\t-\t1.18.1
  rails\t8.1.3\t8.1.4
  range_pin\t1.0.0\t1.5.0
  single_quoted\t2.0.0\t2.1.0
  with_options\t1.24.5\t1.25.0
DIFF

@failures = []

def assert_equal(expected, actual, label)
  if expected == actual
    puts "  PASS #{label}"
  else
    @failures << label
    puts "  FAIL #{label}"
    puts "    expected:\n#{expected.gsub(/^/, '      | ')}"
    puts "    actual:\n#{actual.gsub(/^/, '      | ')}"
  end
end

def run_mode(*args)
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, LIB, *args)
  [stdout, stderr, status]
end

Dir.mktmpdir do |dir|
  gemfile = File.join(dir, "Gemfile")
  original = File.join(FIXTURES, "Gemfile")
  lock_same = File.join(FIXTURES, "Gemfile.lock.same")
  lock_updated = File.join(FIXTURES, "Gemfile.lock.updated")

  puts "unpin strips pins; preserves comments, quoting, options, unpinned gems"
  FileUtils.cp(original, gemfile)
  _, stderr, status = run_mode("unpin", gemfile)
  assert_equal(true, status.success?, "unpin exits 0 (stderr: #{stderr})")
  assert_equal(EXPECTED_UNPINNED, File.read(gemfile), "unpinned Gemfile content")

  puts "repin with unchanged lockfile is stable"
  run_mode("repin", original, lock_same, gemfile)
  assert_equal(EXPECTED_REPIN_SAME, File.read(gemfile), "repin (same versions) content")

  puts "repin with updated lockfile pins resolved versions"
  _, stderr, status = run_mode("repin", original, lock_updated, gemfile)
  assert_equal(true, status.success?, "repin exits 0 (stderr: #{stderr})")
  assert_equal(EXPECTED_REPIN_UPDATED, File.read(gemfile), "repin (updated versions) content")

  puts "comments lists skipped gems"
  stdout, = run_mode("comments", original)
  assert_equal(EXPECTED_COMMENTS, stdout, "comments output")

  puts "lockdiff reports version changes and additions (platform variants deduped)"
  stdout, = run_mode("lockdiff", lock_same, lock_updated)
  assert_equal(EXPECTED_LOCKDIFF, stdout, "lockdiff output")

  puts "unknown mode fails with usage"
  _, stderr, status = run_mode("bogus")
  assert_equal(false, status.success?, "bogus mode exits non-zero")
  assert_equal(true, stderr.include?("Usage:"), "bogus mode prints usage")
end

if @failures.empty?
  puts "\nAll gemfile_edit tests passed."
else
  puts "\n#{@failures.length} failure(s): #{@failures.join(', ')}"
  exit 1
end
