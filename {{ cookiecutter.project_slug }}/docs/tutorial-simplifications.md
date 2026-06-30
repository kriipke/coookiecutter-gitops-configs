# Tutorial Simplifications & Production Notes

This repository is a teaching **base template**, not a turnkey production install.
A few things are deliberately simplified to keep the core lesson -
dev -> stage -> prod chart promotion - front and centre. Each simplification
below is safe for learning and is labelled here so you know exactly what to
harden before running this for real.

None of these are bugs; they are scoped choices. Read
[How It Works](how-it-works.md) first.

## CI scope: applications are gated, add-ons are not

The render gate (`.github/workflows/render-gate.yml`) validates workload
**applications** from `bootstrap/appset-apps.yaml`: for every (app x cluster) it
clones the chart at its pinned tag, runs `helm template` with that cluster's
values, and validates the output. Cluster **add-ons**
(`bootstrap/appset-addons.yaml`) are intentionally **not** in the gate.

Why: application promotion is the core tutorial. Add-ons are platform plumbing -
the same version on every cluster, pulled from upstream public Helm repos - and
they do not participate in the dev -> stage -> prod chart-promotion chain. Adding
add-on rendering would introduce a second CI matrix and a Helm-repo source mode
that distracts from the main lesson.

**Production guidance:** add a similar render gate for `appset-addons.yaml` - a
matrix over the (add-on x cluster) pairs, rendering each against its upstream
chart and the per-cluster `addons/` values file. Treat this as a labelled
follow-on, not a missing feature.

## The CI helper scripts are template-specific

The scripts under `.github/scripts/` are deliberately narrow: they parse **this**
repo's intentionally simple **list-generator** structure in
`bootstrap/appset-apps.yaml` (`.spec.generators[0].list.elements`), not arbitrary
`ApplicationSet` shapes. That keeps them short and readable for teaching.
`appset-matrix.sh`, `stage-prod-lockstep.sh`, and `soak-guard.sh` all read
`.spec.generators[0].list.elements[...]` directly.

If you switch `appset-apps.yaml` to a Git, files, cluster, or matrix generator,
these helpers will no longer find the elements and you must update them to match
the new generator shape.

### Extension points

To scale beyond the tutorial:

- **Generate app entries from files or directories** instead of hand-maintaining
  one list - for example a Git files generator that discovers
  `clusters/<cluster>/apps/*.yaml`. Then rewrite the helpers to enumerate that
  source rather than `list.elements`.
- **Drive the render matrix from the rendered Applications** (for example
  `argocd appset generate`, or the applicationset-controller dry-run output) so
  the gate becomes generator-agnostic.

These are intentionally left out of the starter template; the narrow scripts are
the simpler thing to learn from first.

## Bootstrap app: auto-sync without prune/selfHeal (on purpose)

`bootstrap.yaml` runs with:

```yaml
syncPolicy:
  automated: {}
```

That is auto-sync **enabled** but `prune` and `selfHeal` **off** - a deliberate
safety choice for a learning environment. Combined with
`preserveResourcesOnDeletion: true` on the `ApplicationSet` resources, it means
that while you are experimenting, deleting the bootstrap app or an
`ApplicationSet` will **not** surprise-delete the workloads underneath you.

The asymmetry is intentional: the **generated** Applications still run with
`prune` + `selfHeal` (their `template.spec.syncPolicy` in each appset), so
day-to-day workload drift is corrected. Only the top-level bootstrap/appset
plumbing is non-destructive.

**Production guidance (strict GitOps):** if you want Git to be fully authoritative,
including deletions, set the following on `bootstrap.yaml`:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Make that choice consciously - it means removing an element from an appset (or
deleting the appset) will delete the corresponding workloads.

## Everything runs in the built-in `default` AppProject

Both `bootstrap.yaml` and the generated Applications use `project: default` -
Argo CD's built-in, unrestricted `AppProject` (any source repo, any destination
cluster/namespace, any resource kind). That keeps the template focused on the
promotion model rather than on RBAC.

**Production guidance:** define one or more scoped `AppProject` resources that
whitelist only the source repos, destination clusters/namespaces, and resource
kinds each tier may touch, and point the appsets' `template.spec.project` (and
`bootstrap.yaml`) at them. This is your blast-radius control and a natural place
to separate prod permissions from dev/stage.

## Clusters are targeted by name and must pre-exist

The appsets target clusters **by name**
(`destination.name: {{ cookiecutter.cluster_dev }}` /
`{{ cookiecutter.cluster_stage }}` / `{{ cookiecutter.cluster_prod }}`). Those
names are **not** created by this repo - each cluster must already be registered in
Argo CD under exactly that name (via `argocd cluster add`, or a cluster
`Secret`) before its generated Applications can sync. A name mismatch surfaces as
an Application that cannot find its destination.

**Production guidance:** register clusters as part of your platform bootstrap
(often itself GitOps-managed), and keep the registered names in sync with the
`cluster:` values in `appset-apps.yaml` and the cluster list in
`appset-addons.yaml`. Targeting by label selector instead of by name is a common
next step once you have more than a handful of clusters.

## Summary

| Simplification | In the template | Harden for production by |
| --- | --- | --- |
| Add-on CI | Apps are render-gated; add-ons are not. | Adding a render gate for `appset-addons.yaml`. |
| Helper scripts | Parse the list-generator shape only. | Updating them if you change the generator type. |
| Bootstrap sync | Auto-sync, no `prune`/`selfHeal`. | Enabling `prune` + `selfHeal` for strict GitOps. |
| AppProject | Everything in `default`. | Defining scoped `AppProject` resources. |
| Cluster targeting | By name; clusters must pre-exist. | Registering clusters; considering label selectors. |
