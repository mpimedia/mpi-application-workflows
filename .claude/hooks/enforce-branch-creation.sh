#!/bin/bash

CURRENT_BRANCH=$(cd "$CLAUDE_PROJECT_DIR" && git rev-parse --abbrev-ref HEAD)
PROTECTED_BRANCHES=("main" "master" "develop")

for branch in "${PROTECTED_BRANCHES[@]}"; do
  if [ "$CURRENT_BRANCH" = "$branch" ]; then
    echo "Cannot make changes on '$CURRENT_BRANCH' branch. Please create a new branch first." >&2
    exit 2
  fi
done

exit 0
