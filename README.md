# MPI Application Workflows

Reusable GitHub Actions workflows for MPI Media projects.

## Overview

This repository contains reusable GitHub Actions workflows used across all MPI Media Rails applications.

## Available Workflows

### ci-rails.yml

Full CI pipeline for Rails applications including:
- Ruby security scanning (Brakeman, Bundler Audit)
- JavaScript security scanning (Importmap Audit or Yarn Audit)
- Linting (RuboCop)
- Test suite (RSpec with PostgreSQL)
- Optional Elasticsearch support

**Inputs:**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `elasticsearch` | boolean | `false` | Enable Elasticsearch service for tests |
| `libvips` | boolean | `false` | Install libvips for image processing |
| `security_scan` | boolean | `true` | Run security scans (Brakeman, bundler-audit, JS audit) |
| `lint` | boolean | `true` | Run RuboCop linting |
| `importmap` | boolean | `true` | Run importmap audit for projects using importmap-rails |
| `jsbundling` | boolean | `false` | Run yarn npm audit for projects using jsbundling-rails (esbuild/webpack) |
| `rspec_options` | string | `''` | Additional options passed to the rspec command |

When `elasticsearch: true`, the workflow:
- Reads the Elasticsearch version from `.tool-versions`
- Starts Elasticsearch before running tests
- Sets `ELASTICSEARCH_URL` environment variable

### update-gems.yml

Automated Ruby gem updates (apps schedule it weekly, Monday mornings):
- Runs the centralized `scripts/update-gems` against the calling app's checkout
- Honors the app Gemfile's release-age cooldown (`source "https://rubygems.org", cooldown: N`) —
  Bundler's resolver never selects versions younger than N days
- Flow: unpin exact pins → `bundle update --all` → repin from the resolved lockfile
  (gems with a `#` comment in the Gemfile are never touched)
- Creates a PR listing updated and skipped gems

**Inputs:**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `dry_run` | boolean | `false` | Compute and print the would-be update PR without creating a branch, commit, or PR |

### update-packages.yml

Automated Node.js package updates (apps schedule it weekly, Monday mornings):
- Runs the centralized `scripts/update-packages` against the calling app's checkout
- Honors Yarn's `npmMinimalAgeGate` (`.yarnrc.yml`) — `yarn up <pkg>` resolves to the
  newest gate-compliant release, never to a fresher one
- Creates a PR listing updated packages

**Inputs:**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `dry_run` | boolean | `false` | Compute and print the would-be update PR without creating a branch, commit, or PR |

### lint.yml (this repository's own CI)

Runs on every push to this repository:
- `shellcheck` over `scripts/`
- `actionlint` over `.github/workflows/`
- Fixture tests for the Gemfile pin-editing library (`ruby scripts/test/gemfile_edit_test.rb`)

## Centralized Update Scripts (`scripts/`)

The update workflows do not rely on per-app `bin/` scripts. Each reusable workflow
checks out **this repository at the exact SHA the calling app pinned in `uses:`**
(via `job.workflow_repository` / `job.workflow_sha` — the documented pattern for
reusable workflows referencing their own source) and runs:

- `scripts/update-gems` — orchestrates unpin → resolve → repin (see `scripts/lib/gemfile_edit.rb`)
- `scripts/update-packages` — per-package `yarn up <name> --exact` under the age gate

Pinning an app to a workflow SHA therefore pins the script logic too. Bumping the
pin is the only way an app picks up new update behavior.

### Dependency cooldown escape hatch (CVE response)

The cooldowns delay *fixes* as well as attacks. When a security advisory demands a
release younger than the cooldown window, a human applies it — automation never
bypasses the gate:

- **Ruby:** on a branch, run `bundle update <gem> --cooldown 0`, and note the CVE in
  the PR description.
- **JavaScript:** temporarily add the package to `npmPreapprovedPackages` in
  `.yarnrc.yml` (the entry is visible in the PR diff), run `yarn up <pkg> --exact`,
  and remove the entry after merge.
- **Brand-new packages:** `yarn add` of a package whose *every* version is younger
  than the gate fails with an explicit quarantine error (Yarn ≥ 4.13). Use the same
  `npmPreapprovedPackages` override.

### check-indexes.yml

Migration index checking:
- Runs on PRs that modify migrations
- Ensures all foreign keys have indexes

### deploy-kamal.yml

Deployment via Kamal:
- Deploys Rails applications using Kamal
- Supports staging and production environments
- Uses Tailscale for secure network connectivity to deployment targets
- Optionally pings Tailscale hosts to verify connectivity before deploying
- Configures SSH to automatically accept new Tailscale host keys
- Uses 1Password CLI for secrets management
- Configures Docker buildx with GitHub Actions cache

**Inputs:**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `environment` | string | *(required)* | Target environment (`staging` or `production`) |
| `tailscale_hosts` | string | `""` | Comma-separated Tailscale host addresses to ping for connectivity verification (e.g. `"host1,host2"`) |

## Usage

### CI Pipeline (Standard)

For projects without Elasticsearch:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches:
      - "**"

jobs:
  ci:
    uses: mpimedia/mpi-application-workflows/.github/workflows/ci-rails.yml@main
    secrets: inherit
```

### CI Pipeline (With Elasticsearch)

For projects that need Elasticsearch:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches:
      - "**"

jobs:
  ci:
    uses: mpimedia/mpi-application-workflows/.github/workflows/ci-rails.yml@main
    with:
      elasticsearch: true
    secrets: inherit
```

**Note:** The Elasticsearch version is read from your project's `.tool-versions` file:
```
elasticsearch 9.2.4
```

### CI Pipeline (With jsbundling)

For projects using esbuild or webpack via jsbundling-rails:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches:
      - "**"

jobs:
  ci:
    uses: mpimedia/mpi-application-workflows/.github/workflows/ci-rails.yml@main
    with:
      importmap: false
      jsbundling: true
    secrets: inherit
```

### Gem Updates

```yaml
# .github/workflows/update-gems.yml
name: Update Gems

on:
  schedule:
    - cron: '0 12 * * 1' # Mondays 06:00 CST (UTC-6)
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Dry run (compute and print updates; no branch/PR)'
        required: false
        default: false
        type: boolean

jobs:
  update:
    uses: mpimedia/mpi-application-workflows/.github/workflows/update-gems.yml@<sha> # pin to known-good SHA
    with:
      dry_run: ${{ inputs.dry_run || false }}
    secrets: inherit
```

### Package Updates

```yaml
# .github/workflows/update-packages.yml
name: Update Packages

on:
  schedule:
    - cron: '5 12 * * 1' # Mondays 06:05 CST (UTC-6)
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Dry run (compute and print updates; no branch/PR)'
        required: false
        default: false
        type: boolean

jobs:
  update:
    uses: mpimedia/mpi-application-workflows/.github/workflows/update-packages.yml@<sha> # pin to known-good SHA
    with:
      dry_run: ${{ inputs.dry_run || false }}
    secrets: inherit
```

### Index Checking

```yaml
# .github/workflows/check-indexes.yml
name: Check Indexes

on:
  push:
    branches: [ "main" ]
    paths:
      - 'db/migrate/**.rb'
  pull_request:
    branches: [ "main" ]
    paths:
      - 'db/migrate/**.rb'

jobs:
  check:
    uses: mpimedia/mpi-application-workflows/.github/workflows/check-indexes.yml@main
```

### Deployment (Kamal)

```yaml
# .github/workflows/deploy.yml
name: Deploy

concurrency:
  group: deploy-${{ github.event.inputs.environment }}
  cancel-in-progress: false

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  deploy:
    uses: mpimedia/mpi-application-workflows/.github/workflows/deploy-kamal.yml@main
    with:
      environment: ${{ inputs.environment }}
      tailscale_hosts: "web-server,worker-server"
    secrets: inherit
```

## Deploy Workflow Setup

The deploy workflow uses [Tailscale's GitHub Actions OIDC integration](https://tailscale.com/kb/1258/github-actions) to establish secure connectivity to deployment targets. Consumer repos need the following configuration before using the deploy workflow.

### Required Secrets

| Secret | Description |
|--------|-------------|
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client ID for the GitHub Actions OIDC integration |
| `TS_AUDIENCE` | Tailscale OIDC audience value, used to scope the identity token to your tailnet |
| `OP_SERVICE_ACCOUNT_DEPLOYMENT_TOKEN` | 1Password service account token for secrets management during deploy |

### Consumer Permissions

The deploy workflow requires `id-token: write` so GitHub can issue an OIDC token for Tailscale authentication. Since `secrets: inherit` does not propagate permissions, the **consumer workflow must set this permission itself**:

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    uses: mpimedia/mpi-application-workflows/.github/workflows/deploy-kamal.yml@main
    with:
      environment: ${{ inputs.environment }}
    permissions:
      contents: read
      packages: write
      id-token: write
    secrets: inherit
```

### Creating the Tailscale Federated Identity

1. In the [Tailscale admin console](https://login.tailscale.com/admin/settings/oauth), create a new **OAuth client**.
2. Under the OAuth client settings, add a **GitHub Actions OIDC** provider.
3. Configure the provider to trust tokens from your consumer repository (e.g., `mpimedia/optimus`).
4. Set the **audience** value — this becomes the `TS_AUDIENCE` secret.
5. Copy the **OAuth client ID** — this becomes the `TS_OAUTH_CLIENT_ID` secret.
6. Add both values as repository or organization secrets in GitHub.
7. Tag the OAuth client with `tag:ci` (or the tag matching your Tailscale ACLs) so the ephemeral node gets the correct network access.

## Version Pinning

For stability, you can pin to a specific commit or tag:

```yaml
uses: mpimedia/mpi-application-workflows/.github/workflows/ci-rails.yml@v1.0.0
```

## Contributing

To update workflows:

1. Clone this repository
2. Create a feature branch
3. Make changes and test
4. Create a PR for review
5. After merge, workflows auto-update in projects using `@main`

## License

Internal use only - MPI Media
