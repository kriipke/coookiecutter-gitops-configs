#!/usr/bin/env bash
# semver-label.sh - enforce the atomic-migration rule. A PR that bumps a pinned
# chart tag by a MAJOR version (per the <app>-<semver> contract: MAJOR = breaking
# values change) MUST also modify that app's values file for the affected cluster
# in the same PR. Otherwise the new chart could silently ignore stale values.
#
# Compares bootstrap/appset-apps.yaml between BASE_SHA and the working tree (HEAD).
# Fails (exit 1) on any MAJOR bump that does not migrate its values file.
#
# Env:
#   BASE_SHA   (required) base commit to diff against (PR base)
#   APPSET     (optional) path to appset (default bootstrap/appset-apps.yaml)
#   GH_TOKEN + PR_NUMBER (optional) best-effort PR labelling via `gh`
set -euo pipefail

APPSET="${APPSET:-bootstrap/appset-apps.yaml}"
base="${BASE_SHA:?semver-label: BASE_SHA is required}"

command -v yq >/dev/null || { echo "semver-label: yq (mikefarah) not found" >&2; exit 1; }
[ -f "$APPSET" ] || { echo "semver-label: $APPSET not found" >&2; exit 1; }

changed=$(git diff --name-only "$base" -- . || true)
old_appset=$(git show "${base}:${APPSET}" 2>/dev/null || true)

major_seen=0
violations=0
n=$(yq '.spec.generators[0].list.elements | length' "$APPSET")

for i in $(seq 0 $((n - 1))); do
  app=$(yq ".spec.generators[0].list.elements[$i].appName" "$APPSET")
  env=$(yq ".spec.generators[0].list.elements[$i].environment" "$APPSET")
  cluster=$(yq ".spec.generators[0].list.elements[$i].cluster" "$APPSET")
  new_rev=$(yq ".spec.generators[0].list.elements[$i].targetRevision" "$APPSET")

  # Only pinned release tags (<app>-<semver>); skip branch-tracking (dev/main).
  printf '%s' "$new_rev" | grep -Eq "^${app}-[0-9]+\." || continue

  old_rev=$(printf '%s' "$old_appset" | yq ".spec.generators[0].list.elements[] | select(.appName==\"${app}\" and .environment==\"${env}\") | .targetRevision" 2>/dev/null | head -1)
  [ -n "$old_rev" ] && [ "$old_rev" != "null" ] || continue
  [ "$old_rev" = "$new_rev" ] && continue
  printf '%s' "$old_rev" | grep -Eq "^${app}-[0-9]+\." || continue

  old_major=$(printf '%s' "${old_rev#"${app}"-}" | cut -d. -f1)
  new_major=$(printf '%s' "${new_rev#"${app}"-}" | cut -d. -f1)
  case "$old_major$new_major" in *[!0-9]*) continue ;; esac

  if [ "$new_major" -gt "$old_major" ]; then
    major_seen=1
    vf="clusters/${cluster}/apps/${app}.yaml"
    if printf '%s\n' "$changed" | grep -Fxq "$vf"; then
      echo "OK: MAJOR bump ${old_rev} -> ${new_rev} (${env}) migrates ${vf} in the same PR"
    else
      echo "::error::MAJOR chart bump ${old_rev} -> ${new_rev} for '${app}' on '${env}', but ${vf} was not modified in this PR. Migrate the values file in the SAME PR (atomic migration)."
      violations=$((violations + 1))
    fi
  fi
done

# Best-effort label so reviewers can see breaking PRs at a glance.
if [ "$major_seen" -eq 1 ] && command -v gh >/dev/null && [ -n "${PR_NUMBER:-}" ]; then
  gh pr edit "$PR_NUMBER" --add-label "breaking: values migration required" >/dev/null 2>&1 || true
fi

if [ "$violations" -gt 0 ]; then
  echo "semver-label: ${violations} MAJOR bump(s) missing a values migration" >&2
  exit 1
fi
echo "semver-label: atomic-migration check passed"
exit 0
