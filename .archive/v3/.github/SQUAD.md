# Squad AI Team — Setup Guide

This document covers everything needed to restore the Squad AI team setup on a new machine or after a clean VS Code install.

---

## What is Squad?

Squad is a VS Code AI agent orchestrator (GitHub Copilot chat mode) that manages a team of specialized AI agents for this repo. Team state lives in `.squad/` and travels with the repository — chat history, decisions, agent roles, and routing rules are all committed.

---

## Prerequisites

| Tool                | Purpose                             | Install                                  |
| ------------------- | ----------------------------------- | ---------------------------------------- |
| VS Code             | Editor                              | https://code.visualstudio.com            |
| GitHub Copilot      | AI backbone                         | VS Code extension: `GitHub.copilot`      |
| GitHub Copilot Chat | Chat interface                      | VS Code extension: `GitHub.copilot-chat` |
| Git                 | Version control                     | https://git-scm.com                      |
| Node.js (LTS)       | Required for Squad CLI              | https://nodejs.org                       |
| Squad CLI           | Background watch + issue automation | `npm install -g @bradygaster/squad-cli`  |

---

## VS Code Extensions Required

Install these from the Extensions panel (`Ctrl+Shift+X`):

```
GitHub.copilot
GitHub.copilot-chat
```

Squad runs as a **chat mode** inside GitHub Copilot Chat. The Squad CLI is a companion tool that adds persistent background monitoring and GitHub issue automation.

---

## Squad CLI

The Squad CLI (`@bradygaster/squad-cli`) is an npm package that runs alongside VS Code and handles background work queue monitoring, GitHub issue triage, and auto-assignment.

**Install globally:**

```powershell
npm install -g @bradygaster/squad-cli
```

**Or run without installing:**

```powershell
npx @bradygaster/squad-cli watch              # poll GitHub every 10 minutes (default)
npx @bradygaster/squad-cli watch --interval 5 # poll every 5 minutes
```

**More info:** https://www.npmjs.com/package/@bradygaster/squad-cli

The CLI is optional for local development but recommended if you want Ralph (the work monitor) to keep running between VS Code sessions.

---

## First-Time Machine Setup

### 1. Clone the repo

```powershell
git clone <repo-url>
cd haven
```

### 2. Configure the git union merge driver

Squad uses a `union` merge driver for append-only files so branches merge cleanly. This must be configured **per machine** (it is not stored in the repo):

```powershell
git config merge.union.name "Union merge driver"
git config merge.union.driver "true"
```

Verify it worked:

```powershell
git config merge.union.driver   # should output: true
```

> The `.gitattributes` already maps `.squad/decisions.md`, `history.md`, and log files to `merge=union`. The driver just needs to exist on the machine.

### 3. Open the workspace

Open `haven.code-workspace` (not just the folder) — this loads all workspace-scoped settings.

```powershell
code haven.code-workspace
```

### 4. Verify local tooling (optional)

Optional tools useful when editing playbooks or Terraform locally:

```powershell
# Ansible linting
pip install ansible-lint
ansible-lint --version

# Terraform
terraform --version
```

No local build step or virtual environment is required — haven is an infrastructure/ops repo, not a Python package.

---

## Starting Squad

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Switch to **Squad** mode from the chat mode dropdown
3. Squad reads `.squad/team.md` and resumes from where you left off

The team roster, decisions, and agent histories are all in `.squad/` — committed to the repo — so Squad has full context immediately on any machine.

---

## What Lives Where

| Path                         | Purpose                                | Committed    |
| ---------------------------- | -------------------------------------- | ------------ |
| `.squad/team.md`             | Team roster and project context        | ✅ Yes        |
| `.squad/decisions.md`        | Architecture and process decisions     | ✅ Yes        |
| `.squad/routing.md`          | Work routing rules                     | ✅ Yes        |
| `.squad/ceremonies.md`       | Ceremony definitions                   | ✅ Yes        |
| `.squad/agents/*/charter.md` | Per-agent role and boundaries          | ✅ Yes        |
| `.squad/agents/*/history.md` | Per-agent learnings and context        | ✅ Yes        |
| `.squad/casting/`            | Agent name registry (universe mapping) | ✅ Yes        |
| `.squad/config.json`         | Squad model/preference config          | ✅ Yes        |
| `.squad/log/`                | Session logs                           | ❌ Gitignored |
| `.squad/orchestration-log/`  | Agent spawn logs                       | ❌ Gitignored |
| `.squad/decisions/inbox/`    | Unmerged decision drafts               | ❌ Gitignored |
| `.squad-workstream`          | Local machine activation state         | ❌ Gitignored |

---

## Verifying the Setup

In VS Code:
- Open Squad chat mode → should greet you and show the team
- Open `haven.code-workspace` if Squad does not recognise the team context

From a terminal:

```powershell
# Confirm the workspace opens correctly
code haven.code-workspace

# Optionally verify local tools
ansible --version
terraform --version
```

---

## Troubleshooting

| Symptom                          | Fix                                                           |
| -------------------------------- | ------------------------------------------------------------- |
| Squad doesn't recognise the team | Open `haven.code-workspace` (not just the folder)             |
| git merge conflicts in `.squad/` | Ensure `git config merge.union.driver "true"` is set (step 2) |
