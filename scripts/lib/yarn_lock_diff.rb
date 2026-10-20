#!/usr/bin/env ruby
# frozen_string_literal: true

# Markdown list of the packages whose locked versions differ between two Yarn
# Berry lockfiles, one line per package name, sorted bytewise:
#
#   - tar: 6.2.1 → 7.5.22
#   - node-gyp: 10.2.0 → 13.0.1
#   - make-fetch-happen: 13.0.1 → (removed)
#   - @isaacs/fs-minipass: (new) → 4.0.1
#   - picomatch: 4.0.7 → 4.0.5 ⚠ lower
#
#   ruby yarn_lock_diff.rb before.lock after.lock [max_lines]
#
# update-packages uses it to list what the transitive refresh
# (`yarn up -R '*' '@*/*'`, ISS#46) changed. A name locked at several versions
# shows them all, comma-separated. "⚠ lower" marks a package where a range
# locked in both files now resolves to a lower version: the age gate can
# resolve below a version that is younger than the gate, and a reviewer should
# see that. Prints nothing when the lockfiles lock the same versions. After
# max_lines (default 150) lines it prints a count of the rest, so the first
# large refresh fits in a PR body.
# Fails for a lockfile with no resolution entries, as yarn_lock_names.rb does.

RESOLUTION = /^\s+resolution: "((?:@[^@\/"]+\/)?[^@"]+)@([^"]*)"/
VERSION = /^\s+version: "?([^"\s]+)"?/

# Two maps from each entry's key, version: and resolution: lines: name =>
# sorted unique versions, and descriptor (the key's "name@npm:^1.2" ranges) =>
# version. The app's own workspace entry is skipped.
def read_lock(path)
  versions = Hash.new { |h, k| h[k] = [] }
  by_descriptor = {}
  descriptors = []
  version = nil
  File.foreach(path) do |line|
    if line !~ /^\s/
      descriptors = line.strip.delete_suffix(":").delete('"').split(", ")
      version = nil
    elsif (m = VERSION.match(line))
      version = m[1]
    elsif (m = RESOLUTION.match(line)) && version && !m[2].start_with?("workspace:")
      versions[m[1]] << version
      descriptors.each { |d| by_descriptor[d] = version }
    end
  end
  abort "yarn_lock_diff: no resolution entries in #{path}; not a Yarn Berry lockfile?" if versions.empty?
  [versions.transform_values { |v| v.uniq.sort_by { |s| sortable(s) || Gem::Version.new("0") } }, by_descriptor]
end

def sortable(version)
  Gem::Version.new(version)
rescue ArgumentError
  nil
end

# True when a descriptor of this name, locked in both files, now resolves to a
# lower version. A version that merely leaves the tree is not a lowering.
def lower?(name, before, after)
  before.any? do |descriptor, old|
    next false unless descriptor.start_with?("#{name}@") && after.key?(descriptor)

    a = sortable(after[descriptor])
    b = sortable(old)
    a && b && a < b
  end
end

before_path, after_path, max_arg = ARGV
abort "usage: yarn_lock_diff.rb <before.lock> <after.lock> [max_lines]" unless before_path && after_path
max_lines = Integer(max_arg || 150)

before, before_descriptors = read_lock(before_path)
after, after_descriptors = read_lock(after_path)

lines = (before.keys | after.keys).sort.filter_map do |name|
  old = before.fetch(name, [])
  cur = after.fetch(name, [])
  next if old == cur

  from = old.empty? ? "(new)" : old.join(", ")
  to = cur.empty? ? "(removed)" : cur.join(", ")
  "- #{name}: #{from} → #{to}#{' ⚠ lower' if lower?(name, before_descriptors, after_descriptors)}"
end

puts lines.first(max_lines)
puts "- …and #{lines.length - max_lines} more (see the yarn.lock diff)" if lines.length > max_lines
