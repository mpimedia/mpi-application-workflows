#!/usr/bin/env ruby
# frozen_string_literal: true

# Tests for scripts/apply-update-patch, the publish job's check of the update
# job's untrusted patch. Each case builds a throwaway app repo, makes a patch
# the way the update job does (git format-patch -1), resets to the base, and
# runs the script. Run via:
#
#   ruby scripts/test/apply_update_patch_test.rb

require "fileutils"
require "tmpdir"
require "open3"

SCRIPT = File.expand_path("../apply-update-patch", __dir__)
FIXTURES = File.expand_path("fixtures", __dir__)

# Markaz's shape: dependency files are not listed paths.
RISKY_PATHS = <<~YAML
  paths:
    deploy_and_infrastructure:
      reason: These ship to production servers.
      globs:
        - .github/workflows/**/*
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

def git(dir, *args)
  out, status = Open3.capture2e("git", "-c", "user.name=t", "-c", "user.email=t@t", *args, chdir: dir)
  raise "git #{args.join(' ')} failed: #{out}" unless status.success?

  out
end

# Builds an app repo on `main` (or `ref`), applies `change` as the update
# commit, writes the update job's artifact into in/, and resets to the base.
def scenario(root, ref: "main", branch: "chore/update-gems-2026-10-19-120000",
             title: "chore: Update Ruby gems (2026-10-19)", new_branch: "true",
             base_lock: "Gemfile.lock.same")
  app = File.join(root, "app")
  FileUtils.mkdir_p(File.join(app, "config"))
  git(app, "init", "-q", "-b", ref)
  FileUtils.cp(File.join(FIXTURES, "Gemfile"), File.join(app, "Gemfile"))
  FileUtils.cp(File.join(FIXTURES, base_lock), File.join(app, "Gemfile.lock"))
  File.write(File.join(app, "config/risky_paths.yml"), RISKY_PATHS)
  git(app, "add", ".")
  git(app, "commit", "-q", "-m", "base")
  yield app
  git(app, "add", "-A")
  git(app, "commit", "-q", "-m", "update")
  in_dir = File.join(root, "in")
  FileUtils.mkdir_p(in_dir)
  File.write(File.join(in_dir, "update.patch"), git(app, "format-patch", "-1", "--stdout", "--binary"))
  File.write(File.join(in_dir, "branch"), branch)
  File.write(File.join(in_dir, "title"), title)
  File.write(File.join(in_dir, "body"), "body text")
  File.write(File.join(in_dir, "new_branch"), new_branch)
  git(app, "reset", "-q", "--hard", "HEAD~1")
  [app, in_dir, File.join(root, "out")]
end

def run_script(app, in_dir, out_dir, kind: "gems", ref: "main")
  Open3.capture3({ "GITHUB_REF_NAME" => ref }, "bash", SCRIPT, kind, in_dir, out_dir, chdir: app)
end

def lock_update(app)
  FileUtils.cp(File.join(FIXTURES, "Gemfile.lock.updated"), File.join(app, "Gemfile.lock"))
end

puts "a dependency-only patch is committed on the new branch, labelled from the commit"
Dir.mktmpdir do |root|
  app, in_dir, out_dir = scenario(root) { |a| lock_update(a) }
  File.write(File.join(in_dir, "label"), "risk-low") # forged by the update job: ignored
  _, stderr, status = run_script(app, in_dir, out_dir)
  assert_equal(true, status.success?, "exits 0 (stderr: #{stderr.lines.last(3).join})")
  assert_equal("chore/update-gems-2026-10-19-120000", git(app, "branch", "--show-current").strip, "on the update branch")
  assert_equal("chore: Update Ruby gems (2026-10-19)", git(app, "log", "-1", "--format=%s").strip, "commit message is the checked title")
  assert_equal("Gemfile.lock\n", git(app, "diff", "--name-only", "HEAD~1", "HEAD"), "commit changes only Gemfile.lock")
  assert_equal("risk-high", File.read(File.join(out_dir, "label")), "nokogiri is new: risk-high, not the forged risk-low")
  assert_equal("body text", File.read(File.join(out_dir, "body")), "body passed through")
end

puts "a version-only patch is risk-low"
Dir.mktmpdir do |root|
  app, in_dir, out_dir = scenario(root, base_lock: "Gemfile.lock.updated") do |a|
    lock = File.join(a, "Gemfile.lock")
    File.write(lock, File.read(lock).sub("rails (8.1.4)", "rails (8.1.5)"))
  end
  _, stderr, status = run_script(app, in_dir, out_dir)
  assert_equal(true, status.success?, "exits 0 (stderr: #{stderr.lines.last(3).join})")
  assert_equal("risk-low", File.read(File.join(out_dir, "label")), "no new gem, no listed path")
end

puts "an existing update branch is accepted only as the run's own branch"
Dir.mktmpdir do |root|
  branch = "chore/update-gems-ci-test"
  app, in_dir, out_dir = scenario(root, ref: branch, branch: branch, new_branch: "false") { |a| lock_update(a) }
  _, _, status = run_script(app, in_dir, out_dir, ref: branch)
  assert_equal(true, status.success?, "same branch exits 0")
end
Dir.mktmpdir do |root|
  app, in_dir, out_dir = scenario(root, ref: "chore/update-gems-a", branch: "chore/update-gems-b", new_branch: "false") { |a| lock_update(a) }
  _, _, status = run_script(app, in_dir, out_dir, ref: "chore/update-gems-a")
  assert_equal(false, status.success?, "other branch exits non-zero")
end

puts "rejected patches and metadata"
{
  "a workflow file" => ->(a) {
    lock_update(a)
    FileUtils.mkdir_p(File.join(a, ".github/workflows"))
    File.write(File.join(a, ".github/workflows/evil.yml"), "on: push\n")
  },
  "a file outside the app's dependency files" => ->(a) { File.write(File.join(a, "Rakefile"), "puts 1\n") },
  "a symlink in place of Gemfile.lock" => ->(a) {
    File.delete(File.join(a, "Gemfile.lock"))
    File.symlink("/etc/passwd", File.join(a, "Gemfile.lock"))
  },
  "a package file under the gems kind" => ->(a) { File.write(File.join(a, "package.json"), "{}\n") }
}.each do |label, change|
  Dir.mktmpdir do |root|
    app, in_dir, out_dir = scenario(root) { |a| change.call(a) }
    stdout, _, status = run_script(app, in_dir, out_dir)
    assert_equal(false, status.success?, "#{label}: exits non-zero")
    assert_equal(true, stdout.include?("Update patch rejected"), "#{label}: says why")
    assert_equal(false, File.exist?(File.join(out_dir, "branch")), "#{label}: writes nothing to publish")
  end
end

puts "a rejected patch never reaches the working tree, where the scripts live"
Dir.mktmpdir do |root|
  target = ".mpi-application-workflows/scripts/publish-update-pr"
  app, in_dir, out_dir = scenario(root) do |a|
    lock_update(a)
    FileUtils.mkdir_p(File.join(a, File.dirname(target)))
    File.write(File.join(a, target), "echo pwned\n")
  end
  _, _, status = run_script(app, in_dir, out_dir)
  assert_equal(false, status.success?, "exits non-zero")
  assert_equal(false, File.exist?(File.join(app, target)), "the file was not written")
end

{
  "a branch outside chore/update-gems-*" => { branch: "main" },
  "a branch with a shell metacharacter" => { branch: "chore/update-gems-x;id" },
  "a forged title" => { title: "Bump nothing to see here" },
  "a new branch cut from a non-main ref" => { ref: "chore/update-gems-x" }
}.each do |label, opts|
  Dir.mktmpdir do |root|
    app, in_dir, out_dir = scenario(root, **opts) { |a| lock_update(a) }
    stdout, _, status = run_script(app, in_dir, out_dir, ref: opts.fetch(:ref, "main"))
    assert_equal(false, status.success?, "#{label}: exits non-zero")
    assert_equal(true, stdout.include?("Update patch rejected"), "#{label}: says why")
  end
end

if @failures.empty?
  puts "\nAll apply-update-patch tests passed."
else
  puts "\n#{@failures.length} failure(s): #{@failures.join(', ')}"
  exit 1
end
