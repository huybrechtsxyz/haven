# 2026-06-01 — Command Restructuring Session

**Date:** 2026-06-01
**Participants:** Vincent Huybrechts + team

## Summary

Vincent and team discussed strata #62 children (output, doctor, whoami), decided on env group design, diff/build plan/deploy plan separation.

## Key Decisions

- Remove `strata diff` — redundant alias with no unique value over `build plan`
- Split `strata build plan` — artifact diff only (layer 1), `--artifacts-only` becomes default
- Add `strata deploy plan` — terraform plan against live state (layer 2, replaces diff)
- Add `strata env` group — `env output` + `env state list` + `env state show <resource>`

## Notes

Issue description written by Mal. Decisions captured in `.squad/decisions/inbox/mal-command-restructuring-2026-06-01.md`.
