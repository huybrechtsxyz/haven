---
name: project-gotchas
description: Known pitfalls and hard-won lessons for this repository's tooling (cloud, Terraform, Helm, pipelines, strata). Use before changing infrastructure configuration or pipelines, and add to it when something surprising breaks.
---

# Project gotchas

This file belongs to the team: strata created it once and never changes it. The strata CLI's own pitfalls live in
the `strata` skill, which strata keeps current.

Add one entry per lesson, newest first. Keep each entry short:

- **Symptom:** what you saw (the error text, or what silently went wrong).
- **Cause:** why it happened.
- **Fix:** what to do instead.

## Entries

- **Symptom:** the `strata` skill says a Helm module's `configuration` "replaces the chart's own values, it is not
  merged"; old haven comments said every local-chart default had to be repeated in `configuration`.
  **Cause:** stale. strata 2.7.0 writes `configuration` to `strata-values.yaml` and passes it with `-f` on top of the
  chart's own `values.yaml` (`integrations/helm.py`, `VALUES_FILE`), so Helm merges maps and replaces lists.
  **Fix:** set only what differs from the chart defaults; repeat a whole list if you change one item of it.
- **Symptom:** v1 comments say secrets only resolve inside an `env:` dict, hence the `*-secrets` local charts.
  **Cause:** a strata v1 limitation. v2 resolves `${secret:}` anywhere in Helm values and sends the secret
  branches to Helm on stdin (never disk or argv).
  **Fix:** new modules can put `${secret:}` straight into the chart's own values; the existing `*-secrets`
  charts still work and need no change.
- **Symptom:** an app's own `${VAR}` placeholder (e.g. Gatus config reading pod env vars) fails strata validation.
  **Cause:** every `${...}` is a strata token; a bare v1-style `${KEY}` is not valid in v2.
  **Fix:** write `$${VAR}`; strata unescapes it to a literal `${VAR}` when it resolves values.

<!-- Example:
- **Symptom:** `terraform init` fails with `ContainerNotFound`.
  **Cause:** the state container is `tfstate-platform`, not `tfstate`.
  **Fix:** set `tf_state_container_name: tfstate-platform`.
-->
