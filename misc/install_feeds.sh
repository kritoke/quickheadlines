#!/bin/sh
set -eu

# install_feeds.sh
# Expects MODE, TAG, REPO_URL environment variables to be set (or uses defaults)


: ${REPO_URL:="https://github.com/kritoke/quickheadlines.git"}
: ${ALLOW_REMOTE_FETCH:=false}

DEST=/usr/local/share/quickheadlines/feeds.yml

if [ -f "$DEST" ]; then
  echo "feeds.yml already exists at $DEST; skipping"
  exit 0
fi

if [ "$MODE" = "dev" ] && [ -f /tmp/qh/feeds.yml ]; then
  echo "Copying feeds.yml from cloned repo"
  cp /tmp/qh/feeds.yml "$DEST"
  exit 0
fi

# Determine REF
if [ "$MODE" = "dev" ]; then
  REF=main
elif [ -n "$TAG" ]; then
  REF="$TAG"
else
  LATEST_TAG=$(git ls-remote --sort=v:refname --tags "$REPO_URL" 2>/dev/null | tail -1 | cut -d/ -f3 || true)
  if [ -n "$LATEST_TAG" ]; then
    REF="$LATEST_TAG"
  else
    REF=main
  fi
fi

# Prefer REPO_URL when it's a GitHub URL
if echo "$REPO_URL" | grep -qE "github.com"; then
  OWNER_REPO=$(echo "$REPO_URL" | sed -E 's#https?://github.com/##; s#\.git$##; s#/$##')
  RAW_URL="https://raw.githubusercontent.com/${OWNER_REPO}/${REF}/feeds.yml"
else
  RAW_URL="https://raw.githubusercontent.com/kritoke/quickheadlines/${REF}/feeds.yml"
fi

echo "Fetching feeds.yml from $RAW_URL"
if [ "$ALLOW_REMOTE_FETCH" = "true" ] || [ "$ALLOW_REMOTE_FETCH" = "1" ]; then
  curl -fSL "$RAW_URL" -o "$DEST" || { echo "Error: failed to download feeds.yml from $RAW_URL" >&2; exit 1; }
else
  echo "Remote fetch disabled (ALLOW_REMOTE_FETCH=${ALLOW_REMOTE_FETCH}); not attempting to download feeds.yml from $RAW_URL" >&2
  echo "Error: feeds.yml not available locally and remote fetch is disabled" >&2
  exit 1
fi

echo "feeds.yml installed at $DEST"
