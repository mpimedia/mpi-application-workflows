# MPI Application Workflows

Reusable GitHub Actions workflows for MPI Media projects.

## Overview

This repository contains reusable GitHub Actions workflows used across all MPI Media Rails applications.

## Available Workflows

### ci-rails.yml

Full CI pipeline for Rails applications including:
- Ruby security scanning (Brakeman, Bundler Audit)
- JavaScript security scanning (Importmap Audit)
- Linting (RuboCop)
- Test suite (RSpec with PostgreSQL)

### update-gems.yml

Automated Ruby gem updates:
- Runs daily at 06:00 CST
- Creates PRs for gem updates
- Can be triggered manually

### update-packages.yml

Automated Node.js package updates:
- Runs daily at 06:05 CST
- Creates PRs for package updates
- Can be triggered manually

### check-indexes.yml

Migration index checking:
- Runs on PRs that modify migrations
- Ensures all foreign keys have indexes

## Usage

### CI Pipeline

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

### Gem Updates

```yaml
# .github/workflows/update-gems.yml
name: Update Gems

on:
  schedule:
    - cron: '0 12 * * *'
  workflow_dispatch:

jobs:
  update:
    uses: mpimedia/mpi-application-workflows/.github/workflows/update-gems.yml@main
    secrets: inherit
```

### Package Updates

```yaml
# .github/workflows/update-packages.yml
name: Update Packages

on:
  schedule:
    - cron: '5 12 * * *'
  workflow_dispatch:

jobs:
  update:
    uses: mpimedia/mpi-application-workflows/.github/workflows/update-packages.yml@main
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
