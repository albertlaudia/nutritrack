#!/usr/bin/env bash
# Pre-tool guard. Run before any code changes to ensure the local clone
# is in sync with origin/main. Catches the "I made changes locally
# yesterday that you didn't see" workflow gap.
#
# Usage: bash tools/check_sync.sh
# Exits 0 if synced, 1 if not.

set -e

# Allow skipping the network fetch in offline / airgapped environments.
SKIP_FETCH=${SKIP_SYNC_FETCH:-0}

if [ "$SKIP_FETCH" != "1" ]; then
  git fetch origin main --quiet 2>&1 | tail -3 || true
fi

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "no-remote")

if [ "$REMOTE" = "no-remote" ]; then
  echo "⚠️  No origin/main remote configured. Skipping sync check."
  exit 0
fi

if [ "$LOCAL" != "$REMOTE" ]; then
  echo "❌ Local and remote diverge."
  echo "   Local:  $LOCAL"
  echo "   Remote: $REMOTE"
  echo ""
  echo "Branches in remote but not local:"
  git log --oneline "$LOCAL..$REMOTE" | head -10
  echo ""
  echo "Branches in local but not remote (would be lost on push):"
  git log --oneline "$REMOTE..$LOCAL" | head -10
  echo ""
  echo "Run: git pull --rebase origin main"
  exit 1
fi

# Also check for uncommitted / untracked work.
if [ -n "$(git status --porcelain)" ]; then
  echo "⚠️  Working tree has uncommitted changes:"
  git status --short | head -10
  echo ""
  echo "Commit or stash before switching contexts:"
  echo "  git add -A && git commit -m 'wip: in-progress'"
  echo "  git stash"
  exit 1
fi

echo "✓ Local at $(git rev-parse --short HEAD) matches origin/main"
echo "  Working tree clean"
git log -1 --pretty=format:"  Last commit: %h %s%n  Author:     %an%n  Date:       %ad%n" --date=short
exit 0