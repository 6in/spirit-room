---
phase: 01-infrastructure
plan: 02
subsystem: runtime-validation
tags: [runtime, docker, ssh, redis, tmux, validation]
dependency_graph:
  requires: [01-01]
  provides: [RUN-01, RUN-02, RUN-03, RUN-04]
  affects: []
tech_stack:
  added: []
  patterns: [folder-as-container, flag-based-idempotency, shared-auth-volumes]
key_files:
  created:
    - .planning/phases/01-infrastructure/runtime-evidence.txt
  modified: []
decisions:
  - "SSH password auth (spiritroom) is acceptable for local sandbox; LAN exposure is a documented backlog hardening item"
  - "sshpass used for automated probing; interactive attach verified manually via human checkpoint"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-13"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 1
---

# Phase 01 Plan 02: Runtime Validation Summary

**One-liner:** End-to-end runtime smoke test — Docker open, SSH, Redis ping, tmux 3-window layout, and interactive enter all verified against `spirit-room-base:latest`.

## Objective

Prove that the image produced by Plan 01 and the host CLI (`spirit-room`) work end-to-end: a container starts, SSH connects, Redis is alive, tmux has the three named windows, and `spirit-room enter` attaches interactively.

## What Was Verified

### Container Identity

| Property | Value |
|----------|-------|
| Folder used | `/tmp/spirit-room-test` |
| Container name (derived) | `spirit-room-spirit-room-test` |
| SSH port assigned | `2222` |
| Base image | `spirit-room-base:latest` |

### Task 1 — Automated Probes (RUN-01, RUN-02, RUN-03)

`spirit-room open /tmp/spirit-room-test` started the container cleanly. After a 3-second settle, the following probes were run via SSH and captured to `runtime-evidence.txt`:

| Probe | Command | Result |
|-------|---------|--------|
| SSH connectivity | `echo SSH_OK` inside container | `SSH_OK` — PASS |
| Redis liveliness | `redis-cli ping` inside container | `PONG` — PASS |
| tmux window count | `tmux list-windows -t spirit-room` | 3 windows — PASS |

**tmux window listing:**
```
0: training* (1 panes) [220x50] [layout ad1d,220x50,0,0,0] @0 (active)
1: logs (1 panes) [220x50] [layout ad1e,220x50,0,0,1] @1
2: workspace- (1 panes) [220x50] [layout ad1f,220x50,0,0,2] @2
```

All three windows present (`training`, `logs`, `workspace`) as required by RUN-03.

### Task 2 — Human Checkpoint (RUN-04)

**Status: APPROVED**

The human ran `spirit-room enter /tmp/spirit-room-test`, entered the container, observed all three tmux windows via `Ctrl-b n`, and detached cleanly with `Ctrl-b d`. The interactive SSH + tmux attach path worked as designed.

| Check | Result |
|-------|--------|
| `spirit-room enter` attached to tmux | PASS |
| `training` window visible | PASS |
| `logs` window visible | PASS |
| `workspace` window visible | PASS |
| `Ctrl-b d` detached cleanly | PASS |

### Task 3 — Teardown

`spirit-room close /tmp/spirit-room-test` stopped and removed the container via the CLI's `cmd_close` code path. Verification:

| Check | Command output | Result |
|-------|---------------|--------|
| Container removed | `docker ps -a --filter name=spirit-room-spirit-room-test` → empty | PASS |
| Test dir deleted | `/tmp/spirit-room-test` absent | PASS |
| Evidence preserved | `runtime-evidence.txt` still exists | PASS |

## Requirements Verdict

| Requirement | Description | Verdict |
|-------------|-------------|---------|
| RUN-01 | SSH from host to container succeeds with baked-in password | PASS |
| RUN-02 | Redis running immediately after `spirit-room open` | PASS |
| RUN-03 | tmux session has 3 windows: training, logs, workspace | PASS |
| RUN-04 | `spirit-room enter` attaches to tmux session interactively | PASS |

**Overall verdict: ALL PASS**

## Artifacts

- `.planning/phases/01-infrastructure/runtime-evidence.txt` — raw captured output of all automated probes (docker ps, SSH_OK, PONG, tmux list-windows, structured RESULT_ lines)

## Deviations from Plan

None — plan executed exactly as written. The sshpass fallback in Task 1 was used (sshpass was already installed on the host), and both probe attempts in `runtime-evidence.txt` confirm SSH_OK and PONG on first and second invocation.

## Known Stubs

None. This plan is validation-only; no application code was produced.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes were introduced. The container was ephemeral and torn down in Task 3 per threat mitigation T-01-10.

## Self-Check: PASSED

- `runtime-evidence.txt` exists: confirmed
- Container removed: confirmed (empty docker ps output)
- `/tmp/spirit-room-test` removed: confirmed
- All RUN-* requirements verified via automated probes + human checkpoint
