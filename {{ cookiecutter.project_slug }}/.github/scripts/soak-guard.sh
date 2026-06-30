#!/usr/bin/env bash
# soak-guard.sh - refuse to promote a chart tag to prod unless it is currently,
# or was previously, pinned on stage. This enforces the stage soak: prod can only
# move to a tag that stage has actually run.
#
# It inspects the git history of the appset so that the normal "stage is one
# release ahead of prod" flow works: prod may catch up to a tag stage soaked
# earlier, even though stage has since moved on.
#
# Usage: soak-guard.sh <app> <candidate-prod-tag> [path-to-appset-apps.yaml]
# Requires full git history (checkout with fetch-depth: 0) to see prior stage tags.
#
# TEMPLATE ASSUMPTION: reads this repo's simple list generator
# (.spec.generators[0].list.elements); it is not a generic ApplicationSet parser.
# Switching generator types means updating this script. See
# docs/tutorial-simplifications.md.
set -euo pipefail

app="${1:?usage: soak-guard.sh <app> <candidate-prod-tag> [appset]}"
candidate="${2:?usage: soak-guard.sh <app> <candidate-prod-tag> [appset]}"
APPSET="${3:-bootstrap/appset-apps.yaml}"

command -v yq >/dev/null || { echo "soak-guard: yq (mikefarah) not found" >&2; exit 1; }
[ -f "$APPSET" ] || { echo "soak-guard: $APPSET not found" >&2; exit 1; }

stage_query=".spec.generators[0].list.elements[] | select(.appName==\"${app}\" and .environment==\"stage\") | .targetRevision"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Current stage tag, plus every value the stage element has held across history.
{
  yq "$stage_query" "$APPSET"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    for sha in $(git log --format=%H -- "$APPSET" 2>/dev/null); do
      git show "${sha}:${APPSET}" 2>/dev/null | yq "$stage_query" 2>/dev/null || true
    done
  fi
} | sed '/^$/d' | sort -u > "$tmp" || true

if grep -Fxq "$candidate" "$tmp"; then
  echo "soak-guard: '${candidate}' has been pinned on stage for '${app}'; prod promotion allowed."
  exit 0
fi

{
  echo "soak-guard: refusing to promote '${app}' to prod at '${candidate}'."
  echo "soak-guard: that tag has never been pinned on stage (no soak)."
  echo "soak-guard: stage tags seen for '${app}':"
  sed 's/^/  - /' "$tmp"
} >&2
exit 1
