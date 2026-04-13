---
phase: 01
slug: infrastructure
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-13
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| host filesystem → Docker build context | Files COPYed into image (catalog.md, scripts) become part of every container from this image | Tooling, config — no credentials |
| Docker image → running containers | Packages, sshd_config, entrypoint, CLIs baked into image are inherited by all rooms | SSH config, installed tool versions |
| Network → SSH on host port (0.0.0.0:{port}) | Docker `-p {port}:22` exposes container SSH to host (and by default, LAN) | SSH auth credentials (root:spiritroom) |
| host filesystem → container /workspace | Project folder bind-mounted read-write; container writes persist on host | User project files |
| auth volumes → container | `spirit-room-auth` and `spirit-room-opencode-auth` named volumes mounted into container | AI auth tokens (empty in Phase 1; populated in Phase 2) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-01-01 | Spoofing | sshd password auth (root:spiritroom baked into image) | accept | Local-only sandbox per CLAUDE.md; developer machine only; not exposed to untrusted networks. LAN exposure via 0.0.0.0 binding documented as Phase 2 backlog hardening item. | closed |
| T-01-02 | Tampering | Dockerfile COPY path (wrong path would silently copy wrong catalog) | mitigate | Fixed: `COPY catalog.md /room/catalog.md` (no subdirectory). Acceptance probe `docker run ... test -f /room/catalog.md` confirmed inside built image. Old broken path `catalog/catalog.md` absent in Dockerfile. | closed |
| T-01-03 | Information Disclosure | sshd_config silently misconfigured (sed patterns failing on Ubuntu 24.04) | mitigate | Fixed: replaced `sed -i` with deterministic `echo >> /etc/ssh/sshd_config` appends. Acceptance probe `grep -q "PermitRootLogin yes" /etc/ssh/sshd_config` inside built image returned OK (01-01-SUMMARY). | closed |
| T-01-04 | Denial of Service | apt/npm install layer failures leaving partial image artifacts | mitigate | Build fails fast on layer error (`set -e` in build-base.sh). All 8 acceptance probes in 01-01-SUMMARY passed: every required CLI (claude, node, bun, redis-server, sqlite3, tmux, sshd) verified present in built image. | closed |
| T-01-05 | Elevation of Privilege | `chmod +x` on host CLI | accept | Host CLI (`spirit-room/spirit-room`) is developer-owned; `chmod 755` grants execute to owner without changing ownership or granting new privileges. Standard developer-tool hygiene. | closed |
| T-01-06 | Repudiation | No build provenance in image metadata | accept | Out of scope for v1 local sandbox; image is built locally and not distributed. Commits 86fb032, 23106a4, 3f5f519 provide source-level audit trail. | closed |
| T-01-07 | Spoofing | SSH password auth on Docker-published port (0.0.0.0 binding) | accept | Acceptable for local development sandbox. LAN exposure is documented as a Phase 2 backlog hardening item (bind to 127.0.0.1 explicitly). Container is ephemeral and torn down after use. | closed |
| T-01-08 | Tampering | bind-mounted `/tmp/spirit-room-test` (write access from container to host) | mitigate | Test directory created in `/tmp` (developer-owned, no sensitive content), cleaned up by Task 3 (`spirit-room close` + `rm -rf`). Confirmed removed in 01-02-SUMMARY. | closed |
| T-01-09 | Information Disclosure | `runtime-evidence.txt` contains SSH port and container details | accept | File lives in `.planning/` (project planning dir, developer-only). No credentials written — sshpass password passed via argv, not logged. Content is diagnostic data, not secrets. | closed |
| T-01-10 | Denial of Service | Leftover test container holding a host port | mitigate | Task 1 force-removes `spirit-room-spirit-room-test` before starting (`docker rm -f ... || true`). Task 3 tears down unconditionally via `spirit-room close`. Verified: `docker ps -a` empty after teardown (01-02-SUMMARY). | closed |
| T-01-11 | Repudiation | Manual checkpoint outcome not logged | mitigate | Human typed "approved" at checkpoint; result recorded in 01-02-SUMMARY Task 2 section with explicit PASS table. | closed |
| T-01-12 | Elevation of Privilege | Container runs as root with SSH password auth | accept | Inherent to training room design (agents need root for apt/npm install). Contained by Docker namespace isolation. Consistent with CLAUDE.md tech constraints. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01-01 | T-01-01, T-01-07 | SSH root:spiritroom password baked into image; Docker binds to 0.0.0.0 by default exposing port to LAN. Local sandbox only — developer machine, not production. Phase 2 backlog: add `127.0.0.1:{port}:22` binding to `spirit-room open`. | user | 2026-04-13 |
| AR-01-02 | T-01-05 | `chmod +x` on host CLI is standard developer tooling; no privilege escalation. | user | 2026-04-13 |
| AR-01-03 | T-01-06 | No Docker image provenance metadata in v1; local build only, not distributed. | user | 2026-04-13 |
| AR-01-04 | T-01-09 | runtime-evidence.txt in .planning/ is diagnostic-only with no credentials. | user | 2026-04-13 |
| AR-01-05 | T-01-12 | Container-as-root is required for training agent autonomy; Docker namespace provides isolation boundary. | user | 2026-04-13 |

---

## Phase 2 Hardening Backlog

> Items flagged during Phase 1 that should be addressed in later phases:

- **SSH port binding**: Change `spirit-room open` to use `-p 127.0.0.1:{port}:22` instead of `-p {port}:22` to prevent LAN exposure of SSH. (From T-01-01 / T-01-07)

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-13 | 12 | 12 | 0 | gsd-secure-phase (automated evidence review from PLAN.md + SUMMARY.md) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-13
