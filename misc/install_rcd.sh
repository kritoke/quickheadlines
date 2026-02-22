#!/bin/sh
set -eu

# install_rcd.sh
# Expects MODE, TAG, REPO_URL environment variables to be set (or defaults)

: ${REPO_URL:="https://github.com/kritoke/quickheadlines.git"}
: ${ALLOW_REMOTE_FETCH:=false}

DEST=/usr/local/etc/rc.d/quickheadlines

if [ -f "$DEST" ]; then
  echo "$DEST already exists; skipping"
  exit 0
fi

if [ "$MODE" = "dev" ] && [ -f /tmp/qh/misc/quickheadlines ]; then
  echo "Using rc.d from cloned repository"
  cp /tmp/qh/misc/quickheadlines "$DEST" || { echo "Error: failed to copy rc.d from repo" >&2; exit 1; }
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

# Build RAW URL
if echo "$REPO_URL" | grep -qE "github.com"; then
  OWNER_REPO=$(echo "$REPO_URL" | sed -E 's#https?://github.com/##; s#\.git$##; s#/$##')
  RAW_URL="https://raw.githubusercontent.com/${OWNER_REPO}/${REF}/misc/quickheadlines"
else
  RAW_URL="https://raw.githubusercontent.com/kritoke/quickheadlines/${REF}/misc/quickheadlines"
fi

echo "Fetching rc.d from $RAW_URL"
if [ "$ALLOW_REMOTE_FETCH" = "true" ] || [ "$ALLOW_REMOTE_FETCH" = "1" ]; then
  curl -fSL "$RAW_URL" -o "$DEST" || { echo "Error: failed to download rc.d from $RAW_URL" >&2; exit 1; }
  chmod +x "$DEST"
  echo "rc.d installed at $DEST"
else
  echo "Remote fetch disabled (ALLOW_REMOTE_FETCH=${ALLOW_REMOTE_FETCH}); not attempting to download rc.d from $RAW_URL" >&2
  echo "Error: rc.d not available locally and remote fetch is disabled" >&2
  exit 1
fi
