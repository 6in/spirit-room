---
phase: 01-infrastructure
plan: 01
subsystem: docker-image
tags: [dockerfile, docker-build, ssh, bun, infrastructure]
dependency_graph:
  requires: []
  provides: [spirit-room-base:latest]
  affects: [01-02-runtime-verification]
tech_stack:
  added: []
  patterns: [echo-append-sshd-config, apt-unzip-for-bun]
key_files:
  created: []
  modified:
    - spirit-room/base/Dockerfile
decisions:
  - "Use echo-append instead of sed for sshd_config directives — deterministic on Ubuntu 24.04"
  - "Add unzip to layer 1 apt packages — required by bun.sh installer script"
metrics:
  duration: "~25 minutes (dominated by apt download on slow network)"
  completed: "2026-04-13"
  tasks_completed: 2
  files_modified: 1
---

# Phase 01 Plan 01: Fix Dockerfile and Build Base Image Summary

**One-liner:** Fixed three blocking Dockerfile bugs (catalog COPY path, sshd_config hardening, missing unzip) and built `spirit-room-base:latest` with Node 20, Bun, Claude Code, opencode, SSH, Redis, SQLite, and tmux.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix Dockerfile catalog COPY path and harden sshd_config | 86fb032 | spirit-room/base/Dockerfile |
| 2a | Make host CLI executable (chmod 755) | 23106a4 | spirit-room/spirit-room (permissions) |
| 2b | Build base image | 23106a4 | spirit-room-base:latest |

## Dockerfile Edits Applied

### BUG-1: catalog COPY path (line 47)

**Before:**
```
COPY catalog/catalog.md     /room/catalog.md
```
**After:**
```
COPY catalog.md             /room/catalog.md
```

The build context is `./base`, so `catalog.md` lives at `base/catalog.md` — no subdirectory. The old path `catalog/catalog.md` caused the build to fail at the COPY step.

### BUG-3: sshd_config hardening (lines 36-39)

**Before:**
```
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
```

**After:**
```
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
```

Ubuntu 24.04's default sshd_config uses `Include /etc/ssh/sshd_config.d/*.conf` and may not match the commented patterns the original `sed` expected. Appending directives is order-safe because OpenSSH applies the last matching value.

### BUG-4 (Rule 1 auto-fix): Missing unzip in apt packages (line 10)

**Before:**
```
curl wget git vim nano \
```

**After:**
```
curl wget git vim nano unzip \
```

The `bun.sh` installer script requires `unzip` to extract the Bun binary. This was not in the original apt package list, causing layer 4 to fail with: `error: unzip is required to install bun`. Fixed by adding `unzip` to the base packages layer.

## chmod Result on Host CLI

```
stat -c '%a' spirit-room/spirit-room  →  755
```

## Build Completion

Build completed successfully. Image ID: `6ff7472e87aa`

```
docker images spirit-room-base:latest
IMAGE                     ID             DISK USAGE   CONTENT SIZE
spirit-room-base:latest   6ff7472e87aa       1.61GB             0B
```

## Acceptance Criteria Results

| Check | Command | Expected | Actual | Result |
|-------|---------|----------|--------|--------|
| CLI permissions | `stat -c '%a' spirit-room/spirit-room` | `755` | `755` | PASS |
| Image exists | `docker images spirit-room-base:latest --format '{{.Repository}}:{{.Tag}}'` | `spirit-room-base:latest` | `spirit-room-base:latest` | PASS |
| Entrypoint | `docker image inspect ... --format '{{.Config.Entrypoint}}'` | contains `/entrypoint.sh` | `[/entrypoint.sh]` | PASS |
| catalog.md in image | `docker run ... 'test -f /room/catalog.md && echo OK'` | `OK` | `OK` | PASS |
| start-training.sh executable | `docker run ... 'test -x /room/scripts/start-training.sh && echo OK'` | `OK` | `OK` | PASS |
| All CLIs present | `docker run ... 'command -v claude && ... && echo ALL_OK'` | `ALL_OK` | `ALL_OK` | PASS |
| sshd_config directives | `docker run ... 'grep -q "PermitRootLogin yes" ... && echo OK'` | `OK` | `OK` | PASS |
| Node.js version | `docker run ... 'node --version'` | `v20.x` | `v20.20.2` | PASS |

**Overall verdict: PASS — all 8 acceptance criteria met.**

## Commits

| Hash | Message |
|------|---------|
| 86fb032 | fix(01-01): fix Dockerfile COPY path and harden sshd_config |
| 23106a4 | fix(01-01): make host CLI spirit-room executable (chmod 755) |
| 3f5f519 | fix(01-01): add unzip to apt packages required by bun installer |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing unzip package caused bun installer to fail**

- **Found during:** Task 2 (first build attempt)
- **Issue:** The `bun.sh` install script requires `unzip` to extract the Bun binary archive. The Dockerfile apt-get layer did not include `unzip`. The build failed at layer 4 with: `error: unzip is required to install bun`
- **Fix:** Added `unzip` to the base packages apt-get install list alongside `curl wget git vim nano`
- **Files modified:** `spirit-room/base/Dockerfile` (line 10)
- **Commit:** 3f5f519

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced beyond what was planned and documented in the threat register (T-01-01 through T-01-06).

## Self-Check: PASSED

- spirit-room/base/Dockerfile exists and contains `COPY catalog.md` — FOUND
- spirit-room-base:latest image exists (ID: 6ff7472e87aa) — FOUND
- Commit 86fb032 exists — FOUND
- Commit 23106a4 exists — FOUND
- Commit 3f5f519 exists — FOUND
- All 8 acceptance probes returned expected output — VERIFIED
