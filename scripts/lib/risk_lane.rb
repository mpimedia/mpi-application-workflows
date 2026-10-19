#!/usr/bin/env ruby
# frozen_string_literal: true

# Lane label for an updater PR (ISS#41). Reads the calling app's
# config/risky_paths.yml and the PR's changed files (NUL-separated, as from
# `git diff --name-only -z`) on stdin. Any further arguments name packages that
# appear in the lockfile for the first time, direct or transitive. Prints:
#
#   risk-high   when a changed file matches a glob listed in the config, or a
#               package is new (the config's new_dependency kind; HC decision
#               on ISS#41: the HC merges these)
#   risk-low    when neither holds
#   (nothing)   when the app has no config/risky_paths.yml (it runs no lane gate)
#
#   git diff --name-only -z HEAD -- Gemfile Gemfile.lock | ruby risk_lane.rb config/risky_paths.yml [new_package ...]
#
# Matching mirrors the apps' lib/risky_paths.rb (the reader their risk-lane-gate
# uses): the same File.fnmatch flags and label names. Each app's copy differs in
# validation, not in matching, so the label printed here is the one that app's
# gate accepts. Plain Ruby from the stdlib, so it runs without the app's gems.

require "yaml"

FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_DOTMATCH | File::FNM_EXTGLOB

config_path, *new_packages = ARGV
abort "usage: risk_lane.rb <config/risky_paths.yml> [new_package ...]" unless config_path
exit 0 unless File.exist?(config_path)

paths = YAML.safe_load(File.read(config_path))&.fetch("paths", nil)
abort "risk_lane: #{config_path} has no paths section" unless paths.is_a?(Hash) && paths.any?

files = $stdin.read.split("\0").reject(&:empty?)
abort "risk_lane: no changed files on stdin" if files.empty?

hits = files.flat_map do |file|
  paths.filter_map do |section, spec|
    glob = Array(spec["globs"]).find { |g| File.fnmatch?(g, file, FNMATCH_FLAGS) }
    "#{file} (#{section}: #{glob})" if glob
  end
end
new_packages.reject!(&:empty?)

# The reasons go to stderr (the job log); stdout carries only the label.
if hits.any? || new_packages.any?
  if hits.any?
    warn "risk-high: changed files listed in #{config_path}:"
    hits.each { |hit| warn "  #{hit}" }
  end
  if new_packages.any?
    warn "risk-high: new_dependency, packages new to the lockfile:"
    new_packages.each { |name| warn "  #{name}" }
  end
  puts "risk-high"
else
  warn "risk-low: none of the #{files.size} changed files is listed in #{config_path}, and no package is new"
  puts "risk-low"
end
