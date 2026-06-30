#!/usr/bin/env bash
# values-leaf-diff.sh - ADVISORY check. Flags leaf keys set in a cluster values
# file that the chart's values.yaml no longer defines - a sign that a chart
# upgrade renamed, moved, or removed a key and Helm is now silently ignoring it.
#
# This is best-effort and deliberately conservative to avoid false positives:
# it ignores any key nested under a chart default that is an empty map ({}) or a
# list ([]), because those are free-form and legitimately hold user keys (e.g.
# topologySpreadConstraints, securityContext, podDisruptionBudget,
# resources.limits, nodeSelector). The authoritative guards are the charts repo's
# SemVer-vs-values diff and (recommended) a chart values.schema.json with
# additionalProperties:false, which makes `helm template` itself fail precisely.
#
# Usage: values-leaf-diff.sh <cluster-values.yaml> <chart-values.yaml>
# Emits GitHub Actions ::warning:: lines. Exits 0 unless STALE_KEYS_BLOCKING=true,
# in which case it exits 1 when any suspicious keys are found.
set -euo pipefail

values_file="${1:?usage: values-leaf-diff.sh <cluster-values.yaml> <chart-values.yaml>}"
chart_values="${2:?usage: values-leaf-diff.sh <cluster-values.yaml> <chart-values.yaml>}"
blocking="${STALE_KEYS_BLOCKING:-false}"

command -v yq >/dev/null || { echo "values-leaf-diff: yq (mikefarah) not found" >&2; exit 1; }
[ -f "$values_file" ] || { echo "values-leaf-diff: $values_file not found" >&2; exit 1; }
[ -f "$chart_values" ] || { echo "values-leaf-diff: $chart_values not found" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Every node path in the chart defaults (maps, leaves, and empty containers).
yq '.. | path | join(".")' "$chart_values" | sed '/^$/d' | sort -u > "$tmp/known"

# Free-form prefixes: chart paths whose default is an empty map, any sequence, or
# null (e.g. `resources.limits:` / `podDisruptionBudget: {}`) - the chart invites
# the user to fill these in, so keys nested beneath them are never "stale".
yq '.. | select((tag == "!!map" and length == 0) or tag == "!!seq" or tag == "!!null") | path | join(".")' \
  "$chart_values" | sed '/^$/d' | sort -u > "$tmp/freeform"

# Leaf paths actually set in the cluster values file ("a.b.c = value" lines).
# Keep only real key lines so YAML comments emitted by props output are dropped.
yq -o=props '.' "$values_file" 2>/dev/null \
  | { grep -E '^[A-Za-z_][A-Za-z0-9_.-]* *=' || true; } \
  | sed -E 's/ *=.*//' | sort -u > "$tmp/used"

found=0
while IFS= read -r leaf; do
  [ -n "$leaf" ] || continue
  # Drop numeric list indices to a logical path for matching.
  logical=$(printf '%s' "$leaf" | sed -E 's/\.[0-9]+(\.|$)/\1/g; s/\.$//')

  # Skip if any ancestor (or the path itself) is a free-form prefix.
  skip=0
  prefix=""
  IFS='.' read -ra parts <<< "$logical"
  for p in "${parts[@]}"; do
    if [ -z "$prefix" ]; then prefix="$p"; else prefix="$prefix.$p"; fi
    if grep -Fxq "$prefix" "$tmp/freeform"; then skip=1; break; fi
  done
  [ "$skip" -eq 1 ] && continue

  # OK if the logical path is a known chart node.
  grep -Fxq "$logical" "$tmp/known" && continue

  echo "::warning file=${values_file}::values key '${leaf}' is not defined by the chart's values.yaml; it may be a stale/renamed key that Helm will silently ignore."
  found=$((found + 1))
done < "$tmp/used"

if [ "$found" -gt 0 ]; then
  echo "values-leaf-diff: ${found} suspicious key(s) in ${values_file}" >&2
  if [ "$blocking" = "true" ]; then
    echo "values-leaf-diff: failing because STALE_KEYS_BLOCKING=true" >&2
    exit 1
  fi
fi
exit 0
