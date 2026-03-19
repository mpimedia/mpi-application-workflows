# AGENTS.md

Instructions for all AI coding agents (Claude Code, Copilot, Codex, and others) working in this repository.

## Project Identity

MPI Application Workflows provides **shared, reusable GitHub Actions CI/CD workflows** consumed by all MPI Media Rails applications. This is NOT a Rails app — it contains only GitHub Actions YAML workflow files. Changes here affect 6+ consumer repos.

## Workflows

| Workflow | Purpose |
|----------|---------|
| `ci-rails.yml` | Full CI pipeline: tests, linting, security scanning, Elasticsearch support |
| `update-gems.yml` | Daily automated gem updates via PR |
| `update-packages.yml` | Daily automated package updates via PR |
| `check-indexes.yml` | Validate migration indexes |
| `deploy-kamal.yml` | Kamal deployment to staging/production |

All are callable workflows (`workflow_call`) referenced by consumers via pinned SHA.

## MPI Application Ecosystem

| Project | Repo | Relationship |
|---------|------|-------------|
| **CI Workflows** (this repo) | `mpimedia/mpi-application-workflows` | Shared workflows |
| Optimus | `mpimedia/optimus` | Consumer |
| Markaz | `mpimedia/avails_server` | Consumer |
| SFA | `mpimedia/wpa_film_library` | Consumer |
| Garden | `mpimedia/garden` | Consumer |
| Harvest | `mpimedia/harvest` | Consumer |
| Markaz CRM | `mpimedia/markez-crm` | Consumer |

## Pre-Commit Requirements

1. Validate YAML syntax
2. Test from at least one consumer repo's feature branch
3. Verify no breaking changes to inputs/outputs

## PR Instructions

- PR title: under 70 characters, descriptive
- PR body: Summary, Changes, Consumer Impact Assessment
- Note which consumer repos are affected

## Review Guidelines

### P0 — Must Fix
- Breaking changes to workflow inputs/outputs without consumer coordination
- Secrets or credentials in workflow files
- Removal of steps that consumers depend on
- Workflow filename changes

### P1 — Should Fix
- Missing input validation
- Inefficient caching strategy
- Missing failure notifications

### P2 — Consider
- Documentation improvements
- Workflow optimization

## Anti-Patterns (Hard Boundaries)

- **Never make breaking changes** to workflow inputs/outputs without coordinating with all consumers
- **Never change workflow filenames** — consumers reference by path
- **Never add secrets to workflow files** — use `secrets` context only
- **Never remove workflow steps** without deprecation notice
- **Never merge without testing** in at least one consumer repo
- **Never change version matrix** without checking all consumers' `.tool-versions`
- **Never commit directly to `main`** — feature branches with PRs only

## Agent Attribution (Required — No Exceptions)

Every AI agent **must** include attribution on all work:

- **Commits**: `Co-Authored-By: Agent Name <email>` trailer
- **PRs**: Agent name in description footer
- **Comments**: Attribution line
