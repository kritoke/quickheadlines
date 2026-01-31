#!/usr/bin/env bash
set -euo pipefail

# Find any elm.js files in the repo other than public/elm.js and fail if found.
strays=()
while IFS= read -r -d '' f; do
  # Normalize path (strip leading ./)
  path="${f#./}"
  if [[ "$path" != public/elm.js ]]; then
    strays+=("$path")
  fi
done < <(find . -type f -name 'elm.js' -print0)

if [ ${#strays[@]} -ne 0 ]; then
  echo "Found stray Elm bundles in the repository:" >&2
  for p in "${strays[@]}"; do
    echo "  - $p" >&2
  done
  echo "Only 'public/elm.js' is allowed committed. Remove or relocate the stray files." >&2
  exit 1
fi

echo "✓ No stray elm.js bundles found."
