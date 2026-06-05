#!/usr/bin/env ruby
# frozen_string_literal: true

# Gemfile pin manipulation for the MPI dependency-update automation.
#
# MPI Gemfiles pin direct gems to exact versions (e.g. gem "rails", "8.1.3").
# Exact pins block `bundle update --all` from moving anything, so the update
# flow is: unpin -> resolve (Bundler enforces the Gemfile source cooldown) ->
# repin from what Gemfile.lock actually resolved.
#
# Modes:
#   unpin <gemfile>                          Strip version pins in place
#   repin <original> <lockfile> <gemfile>    Rewrite <gemfile> from <original>,
#                                            pinning to versions in <lockfile>
#   comments <gemfile>                       List skipped gems (name<TAB>comment)
#   lockdiff <old_lock> <new_lock>           List changes (name<TAB>old<TAB>new)
#
# Rules (matching the legacy per-app scripts):
#   - Lines containing a "#" comment are never modified ("skip" semantics —
#     a comment marks a deliberate hold, e.g. breaking changes).
#   - Gems without a version pin never gain one (the lockfile governs them).
#   - Quoting style and trailing options (require:, group:, etc.) are preserved.
#   - Multi-requirement pins (">= 1.0", "< 2.0") collapse to one exact pin on
#     repin — MPI convention is exact pins.

require "bundler"

GEM_LINE = /\A(\s*)gem(\s+)(["'])([A-Za-z0-9_\-.]+)\3(.*)\z/m
VERSION_REQ = /\A(?:~>|>=|<=|!=|>|<|=)?\s*\d[A-Za-z0-9.\-]*\z/

# Splits the text following the gem name into [version_args, remainder].
# Consumes consecutive quoted arguments that look like version requirements
# and stops at the first argument that does not.
def split_version_args(rest)
  version_args = ""
  remainder = rest
  while (match = remainder.match(/\A(\s*,\s*)(["'])([^"']*)\2/))
    break unless match[3].match?(VERSION_REQ)

    version_args += match[0]
    remainder = match.post_match
  end
  [version_args, remainder]
end

def parse_gem_line(line)
  return nil if line.include?("#") # commented lines are never touched
  return nil unless (match = line.match(GEM_LINE))

  indent, space, quote, name, rest = match.captures
  version_args, remainder = split_version_args(rest)
  return nil if version_args.empty? # unpinned gems never gain pins

  { indent: indent, space: space, quote: quote, name: name,
    version_args: version_args, remainder: remainder }
end

def locked_versions(lockfile_path)
  parser = Bundler::LockfileParser.new(File.read(lockfile_path))
  parser.specs.each_with_object({}) do |spec, versions|
    # Native gems appear once per platform with identical versions; keep the
    # highest in case a platform lags a release.
    version = Gem::Version.new(spec.version.to_s)
    versions[spec.name] = version if !versions[spec.name] || version > versions[spec.name]
  end
end

def unpin(gemfile_path)
  lines = File.readlines(gemfile_path)
  updated = lines.map do |line|
    parsed = parse_gem_line(line)
    next line unless parsed

    "#{parsed[:indent]}gem#{parsed[:space]}#{parsed[:quote]}#{parsed[:name]}#{parsed[:quote]}#{parsed[:remainder]}"
  end
  File.write(gemfile_path, updated.join)
end

def repin(original_path, lockfile_path, gemfile_path)
  versions = locked_versions(lockfile_path)
  lines = File.readlines(original_path)
  updated = lines.map do |line|
    parsed = parse_gem_line(line)
    next line unless parsed

    resolved = versions[parsed[:name]]
    unless resolved
      warn "gemfile_edit: #{parsed[:name]} not found in #{lockfile_path}; keeping original pin"
      next line
    end

    quote = parsed[:quote]
    "#{parsed[:indent]}gem#{parsed[:space]}#{quote}#{parsed[:name]}#{quote}, #{quote}#{resolved}#{quote}#{parsed[:remainder]}"
  end
  File.write(gemfile_path, updated.join)
end

def comments(gemfile_path)
  File.readlines(gemfile_path).each do |line|
    next unless (match = line.match(GEM_LINE))
    next unless line.include?("#")

    comment = line[line.index("#")..].strip
    puts "#{match[4]}\t#{comment}"
  end
end

def lockdiff(old_lock_path, new_lock_path)
  old_versions = locked_versions(old_lock_path)
  new_versions = locked_versions(new_lock_path)
  (old_versions.keys | new_versions.keys).sort.each do |name|
    old_version = old_versions[name]&.to_s || "-"
    new_version = new_versions[name]&.to_s || "-"
    puts "#{name}\t#{old_version}\t#{new_version}" if old_version != new_version
  end
end

def usage!
  abort <<~USAGE
    Usage:
      gemfile_edit.rb unpin <gemfile>
      gemfile_edit.rb repin <original_gemfile> <lockfile> <gemfile>
      gemfile_edit.rb comments <gemfile>
      gemfile_edit.rb lockdiff <old_lockfile> <new_lockfile>
  USAGE
end

case ARGV[0]
when "unpin"
  usage! unless ARGV.length == 2
  unpin(ARGV[1])
when "repin"
  usage! unless ARGV.length == 4
  repin(ARGV[1], ARGV[2], ARGV[3])
when "comments"
  usage! unless ARGV.length == 2
  comments(ARGV[1])
when "lockdiff"
  usage! unless ARGV.length == 3
  lockdiff(ARGV[1], ARGV[2])
else
  usage!
end
