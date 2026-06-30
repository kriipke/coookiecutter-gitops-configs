# {{ cookiecutter.platform_name }} GitOps - Documentation

This directory documents the {{ cookiecutter.platform_name }} Argo CD GitOps
configuration repository: what it contains, how Argo CD turns it into running
workloads, and how you develop applications and promote them from dev to prod.

## Contents

- [How It Works](how-it-works.md) - the two-repository model, the bootstrap
  flow, the two `ApplicationSet` resources, multi-source applications, and how
  clusters, namespaces, and sync policies fit together.
- [Developing & Promoting Apps](developing-and-promoting-apps.md) - the
  day-to-day workflow: changing an app on dev, adding a brand-new application,
  and promoting both chart versions and configuration from dev -> stage -> prod
  (plus rollback).
- [Promoting Chart Upgrades Safely](promoting-chart-upgrades.md) - the SemVer
  contract, the CI render gate, and the runbook for upgrades that change the
  chart's values structure (breaking changes) - including the charts-repo CI.
- [Tutorial Simplifications & Production Notes](tutorial-simplifications.md) -
  the choices this base template makes for teaching clarity (add-on CI scope, the
  template-specific helper scripts, bootstrap sync behaviour, the `default`
  AppProject, by-name cluster targeting) and how to harden each for production.

## TL;DR

- This repository (`{{ cookiecutter.repo_appsets }}`) holds **configuration**:
  two `ApplicationSet` resources under `bootstrap/` and per-cluster Helm values
  under `clusters/`.
- Application **charts** live in a separate repository
  (`{{ cookiecutter.repo_charts }}`); add-on charts come from upstream public
  Helm repositories.
- Argo CD is started once by applying `bootstrap.yaml`; everything else is
  discovered and reconciled automatically from Git.
- `{{ cookiecutter.cluster_dev }}` continuously tracks the charts repo's `main`
  branch; `{{ cookiecutter.cluster_stage }}` and `{{ cookiecutter.cluster_prod }}`
  pin released chart tags. Promotion = moving a pinned tag forward.

See the top-level `README.md` for the bootstrap command and repository
references.
