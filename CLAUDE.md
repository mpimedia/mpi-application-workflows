# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Project

MPI Application Workflows provides shared, reusable GitHub Actions CI/CD workflows consumed by all MPI Media Rails applications. Changes to these workflows affect the entire ecosystem — Optimus, Markaz, SFA, Garden, Harvest, and Markaz CRM all pin to a specific commit SHA for stability.

## Workflows

| Workflow | Purpose | Key Inputs |
|----------|---------|------------|
| `ci-rails.yml` | CI pipeline (tests, lint, security) | `elasticsearch`, `libvips`, `security_scan`, `lint`, `jsbundling` |
| `update-gems.yml` | Daily automated gem updates | — |
| `update-packages.yml` | Daily automated package updates | — |
| `check-indexes.yml` | Migration index validation | — |
| `deploy-kamal.yml` | Kamal deployment (staging/production) | `environment` |

All workflows support failure notifications via Postmark API.

## How Consumers Use These Workflows

Consumer repos (e.g., Optimus, SFA) reference workflows by SHA:

```yaml
uses: mpimedia/mpi-application-workflows/.github/workflows/ci-rails.yml@<SHA>
```

Changing a workflow here affects all consumers on that SHA. Consumers update by changing their pinned SHA in all 4 workflow files simultaneously.

## Commands

```bash
# Validate YAML syntax
yamllint .github/workflows/

# Test workflow changes by pushing to a feature branch and running
# the workflow from a consumer repo's feature branch
```

There are no tests or linting tools in this repo. Validation happens when consumer repos run the workflows.

## Required Workflow

Before committing:
1. Validate YAML syntax
2. Test the workflow from at least one consumer repo's feature branch
3. Ensure no breaking changes to workflow inputs/outputs

## Permissions and Autonomy

### Branch-Based Permissions

**On feature branches:** Full autonomy granted — edit files, commit, push.

**On `main` branch:** Ask before making any changes.

## Commit and PR Standards

Commit messages must be verbose and detailed, following this format:

```
Brief summary (50 chars or less)

- What changed and why
- Which workflows affected
- Consumer impact assessment

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Agent Attribution (Required — No Exceptions)

Every AI agent **must** include `Co-Authored-By` trailer on commits, agent name in PR footers, and attribution on issue/PR comments.

## Anti-Patterns (Hard Boundaries)

These are non-negotiable. Never do any of the following:

- **Never make breaking changes to workflow inputs/outputs** without coordinating with all consumer repos first
- **Never change the workflow filenames** — consumers reference them by path
- **Never add secrets or credentials to workflow files** — use `secrets` context only
- **Never remove workflow steps** that consumers depend on without deprecation notice
- **Never merge without testing** in at least one consumer repo's feature branch
- **Never change the Ruby/Node/Postgres version matrix** without checking all consumers' `.tool-versions`
- **Never commit directly to `main`** — always use feature branches with PRs

## MPI Application Ecosystem

| Project | Repo | Relationship |
|---------|------|-------------|
| **CI Workflows** (this repo) | `mpimedia/mpi-application-workflows` | Shared workflows |
| Optimus | `mpimedia/optimus` | Consumer (pins by SHA) |
| Markaz | `mpimedia/avails_server` | Consumer |
| SFA | `mpimedia/wpa_film_library` | Consumer |
| Garden | `mpimedia/garden` | Consumer |
| Harvest | `mpimedia/harvest` | Consumer |
| Markaz CRM | `mpimedia/markez-crm` | Consumer |
| Infrastructure | `mpimedia/mpi-infrastructure` | Separate (Terraform) |
