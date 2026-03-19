# GitHub Copilot Instructions for MPI Application Workflows

This file provides guidance for GitHub Copilot coding agents working with this repository.

## Project Overview

**MPI Application Workflows** provides shared, reusable GitHub Actions CI/CD workflows consumed by all MPI Media Rails applications (Optimus, Markaz, SFA, Garden, Harvest, Markaz CRM). This is NOT a Rails app — it contains only GitHub Actions YAML workflow files.

## Workflows

| Workflow | Purpose |
|----------|---------|
| `ci-rails.yml` | Full CI pipeline (tests, lint, security, optional Elasticsearch) |
| `update-gems.yml` | Daily automated gem updates via PR |
| `update-packages.yml` | Daily automated package updates via PR |
| `check-indexes.yml` | Validate migration indexes |
| `deploy-kamal.yml` | Kamal deployment to staging/production |

All are callable workflows (`workflow_call`) pinned by SHA in consumer repos.

## Key Constraints

- **Breaking changes require consumer coordination** — 6+ repos depend on these workflows
- **Workflow filenames must not change** — consumers reference by path
- **Never add secrets to workflow files** — use `secrets` context
- **Test from a consumer repo** before merging — no local test infrastructure exists
- **Version reads from `.tool-versions`** — workflows extract Ruby, Node, PostgreSQL, and Elasticsearch versions from the consumer's `.tool-versions` file

## Agent Attribution (Required)

Every AI agent **must** include attribution: `Co-Authored-By` trailer on commits, agent name in PR footers.

## Consumer Repos

Optimus, Markaz (avails_server), SFA (wpa_film_library), Garden, Harvest, Markaz CRM (markez-crm) — all under `mpimedia/` org.
