#!/usr/bin/env ruby
# frozen_string_literal: true

# Package names in a Yarn Berry lockfile (yarn.lock), one per line, sorted
# bytewise and unique. Read from each entry's `resolution:` line, so direct and
# transitive packages count alike; the app's own workspace entry is included
# and cancels out when two lockfiles are compared.
#
#   ruby yarn_lock_names.rb yarn.lock
#
# update-packages compares the names before and after an update: a name that
# appears for the first time is a new_dependency (config/risky_paths.yml
# kinds), which makes the PR risk-high (ISS#41). Fails rather than printing
# nothing for a lockfile with no resolution entries (a Yarn Classic lockfile,
# say), since an empty list would make every package look new.

RESOLUTION = /^\s+resolution: "((?:@[^@\/"]+\/)?[^@"]+)@/

path = ARGV.fetch(0) { abort "usage: yarn_lock_names.rb <yarn.lock>" }
names = File.read(path).scan(RESOLUTION).flatten.uniq.sort
abort "yarn_lock_names: no resolution entries in #{path}; not a Yarn Berry lockfile?" if names.empty?

puts names
