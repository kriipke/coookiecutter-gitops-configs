#!/usr/bin/env bash
# stage-prod-lockstep.sh - verify each app's stage and prod values files are
# identical except for an allowlist of environment-identity keys (default:
# ui.message). Drift means stage is no longer soaking what prod runs.
#
# Self-discovers the stage/prod cluster names and the app list from the appset,
# and compares semantic content (JSON, key-sorted) so comments and key order do
# not matter.
#
# Usage: stage-prod-lockstep.sh [path-to-appset-apps.yaml]
# Env:
#   LOCKSTEP_ALLOWLIST            comma-separated yq paths to ignore (default: ui.message)
#   STAGE_PROD_LOCKSTEP_BLOCKING  "true" to exit 1 on drift (default: warn, exit 0)
set -euo pipefail

APPSET="${1:-bootstrap/appset-apps.yaml}"
allowlist="${LOCKSTEP_ALLOWLIST:-ui.message}"
blocking="${STAGE_PROD_LOCKSTEP_BLOCKING:-false}"

command -v yq >/dev/null || { echo "lockstep: yq (mikefarah) not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "lockstep: jq not found" >&2; exit 1; }
[ -f "$APPSET" ] || { echo "lockstep: $APPSET not found" >&2; exit 1; }

stage_cluster=$(yq '.spec.generators[0].list.elements[] | select(.environment=="stage") | .cluster' "$APPSET" | head -1)
prod_cluster=$(yq '.spec.generators[0].list.elements[] | select(.environment=="prod") | .cluster' "$APPSET" | head -1)
if [ -z "$stage_cluster" ] || [ -z "$prod_cluster" ]; then
  echo "lockstep: could not find stage/prod clusters in $APPSET" >&2
  exit 1
fi

# Build a yq deletion expression from the allowlist, e.g. ". | del(.ui.message)".
del_expr="."
IFS=',' read -ra keys <<< "$allowlist"
for k in "${keys[@]}"; do
  k=$(printf '%s' "$k" | tr -d '[:space:]')
  [ -n "$k" ] || continue
  del_expr="$del_expr | del(.$k)"
done

apps=$(yq '.spec.generators[0].list.elements[] | select(.environment=="prod") | .appName' "$APPSET" | sort -u)

drift=0
for app in $apps; do
  [ -n "$app" ] || continue
  s="clusters/${stage_cluster}/apps/${app}.yaml"
  p="clusters/${prod_cluster}/apps/${app}.yaml"
  if [ ! -f "$s" ] || [ ! -f "$p" ]; then
    echo "::warning::lockstep: missing values file for '${app}' (${s} or ${p})"
    continue
  fi
  sn=$(yq -o=json "$del_expr" "$s" | jq -S .)
  pn=$(yq -o=json "$del_expr" "$p" | jq -S .)
  if [ "$sn" != "$pn" ]; then
    echo "::warning::lockstep: stage and prod values for '${app}' differ outside the allowlist (${allowlist}):"
    diff <(printf '%s\n' "$sn") <(printf '%s\n' "$pn") || true
    drift=$((drift + 1))
  fi
done

if [ "$drift" -gt 0 ]; then
  echo "lockstep: ${drift} app(s) drifted between stage and prod" >&2
  if [ "$blocking" = "true" ]; then
    echo "lockstep: failing because STAGE_PROD_LOCKSTEP_BLOCKING=true" >&2
    exit 1
  fi
fi
exit 0
