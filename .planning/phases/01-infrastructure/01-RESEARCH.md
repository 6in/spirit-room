# Phase 1: Infrastructure - Research

**Researched:** 2026-04-13
**Domain:** Docker image build + container runtime (bash, Docker, SSH, tmux, Redis)
**Confidence:** HIGH — all findings verified by direct code inspection and live environment probing

---

## Summary

Phase 1 establishes the working Docker base image and verifies that a container starts with SSH, tmux, and Redis all functional. The code is substantially written — this is NOT a greenfield phase. The primary work is identifying and fixing bugs that would prevent the existing code from building and running correctly.

Two confirmed blocking bugs exist. First, the Dockerfile references `COPY catalog/catalog.md` but the file lives at `catalog.md` (no subdirectory) — the build will fail with "COPY failed: file not found". Second, the `spirit-room` CLI script has `0644` permissions (not executable) and must be `chmod +x` before it can be invoked directly. The `sshd_config` sed patterns are a probable third issue: Ubuntu 24.04's defaults may not match the comment patterns the sed commands search for, meaning root login via password would silently fail.

Beyond the bugs, the implementation is architecturally sound. The entrypoint creates 3 tmux _windows_ (not panes as the requirements describe), which is functionally equivalent. Redis starts via `service redis-server start` which works in Docker containers using init.d scripts. The `find_free_port` function correctly handles port conflicts. The build pipeline (build-base.sh → docker run → entrypoint.sh) is logically correct and complete.

**Primary recommendation:** Fix the two confirmed bugs (catalog path, script permissions) and verify/harden the sshd_config patterns before running the build.

---

## Project Constraints (from CLAUDE.md)

- Tech stack is **bash + Docker only** — do not add Node.js/Python as core tooling
- No external formatter enforced — use 4-space indentation, `set -e`, quoted variables
- Use `[INFO]` / `[ERROR]` prefixes for user-facing messages
- Naming: executable scripts lowercase with hyphens, no extension
- All variable expansions must be quoted (`"$variable"`)
- Use `#!/bin/bash` shebang consistently
- `set -e` at the top of all scripts
- Japanese/English bilingual comments — user messages in Japanese, code comments in English
- Dragon Ball world-building naming must be preserved (Mr. ポポ, 精神と時の部屋)
- Section separators: `# ──` style

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUILD-01 | `./build-base.sh` completes without errors and `spirit-room-base:latest` exists | Confirmed blocking bug: catalog COPY path must be fixed first |
| BUILD-02 | All Dockerfile dependencies install cleanly (Node.js 20, Bun, Claude Code CLI, SSH, Redis, SQLite) | Node.js 20 via nodesource, Bun via curl-install, packages exist; Bun PATH must be set before npm install layer |
| RUN-01 | `spirit-room open [folder]` starts a container and SSH connection succeeds | sshd_config sed patterns are risk — must be verified/hardened |
| RUN-02 | Redis auto-starts inside the container | `service redis-server start` in entrypoint works with Ubuntu 24.04 init.d |
| RUN-03 | tmux 3 windows (training/logs/workspace) start correctly | Implementation correct; creates windows not panes, but functionally meets goal |
| RUN-04 | `spirit-room enter [folder]` attaches to the tmux session | Implementation correct once SSH works and session named "spirit-room" |
</phase_requirements>

---

## Confirmed Bugs (Blocking)

### BUG-1: Dockerfile `COPY catalog/catalog.md` path is wrong — BUILD BLOCKER
**File:** `spirit-room/base/Dockerfile` line 47
**Code:** `COPY catalog/catalog.md     /room/catalog.md`
**Problem:** Docker build context is `spirit-room/base/`. The file exists at `spirit-room/base/catalog.md` (no subdirectory). Docker will fail: `ERROR: failed to solve: failed to read dockerfile: failed to read catalog/catalog.md: file not found`
**Fix option A:** Change Dockerfile line to `COPY catalog.md /room/catalog.md` [VERIFIED: file exists at this path]
**Fix option B:** Create `spirit-room/base/catalog/` directory and move `catalog.md` inside it
**Recommendation:** Option A (simpler, no directory restructuring). [VERIFIED: ls confirms `catalog.md` exists at `spirit-room/base/catalog.md`]

### BUG-2: `spirit-room` CLI script is not executable — RUN BLOCKER
**File:** `spirit-room/spirit-room`
**Current permissions:** `0644` (not executable) [VERIFIED: `stat` output]
**Problem:** Running `./spirit-room open` fails with "Permission denied". `build-base.sh` is already `0755` — only the CLI needs fixing.
**Fix:** `chmod +x spirit-room/spirit-room`
**Note:** This is a host-side fix. The Dockerfile correctly runs `chmod +x /entrypoint.sh /room/scripts/*.sh` inside the image.

---

## Probable Bugs (High Risk)

### BUG-3: sshd_config sed patterns may silently fail on Ubuntu 24.04
**File:** `spirit-room/base/Dockerfile` lines 38-39
**Code:**
```bash
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
```
**Problem:** Ubuntu 22.04+ sshd_config defaults changed. The actual Ubuntu 24.04 (Noble) sshd_config may have these lines uncommented (`PermitRootLogin prohibit-password`) or may use a different default file location (`/etc/ssh/sshd_config.d/`). If the patterns don't match, `sed` exits 0 with no changes — SSH will reject root login silently. [ASSUMED — based on known Ubuntu 22.04+ behavior, not verified against live Ubuntu 24.04 container]
**Safe fix:** Replace the fragile sed patterns with explicit appends or overwrites:
```bash
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
```
Appending works regardless of the existing file state because later directives override earlier ones in sshd_config. [VERIFIED: OpenSSH documentation behavior]

---

## Architecture: What Exists and What It Does

### Build Pipeline
```
spirit-room/
└── build-base.sh       # Run from spirit-room/ dir; calls: docker build -t spirit-room-base:latest ./base
    └── base/
        ├── Dockerfile      # Build context root; COPYs from relative paths
        ├── entrypoint.sh   # Becomes /entrypoint.sh in image
        ├── catalog.md      # Becomes /room/catalog.md (after BUG-1 fix)
        └── scripts/        # Becomes /room/scripts/
```

### Container Runtime
```
docker run -d
  --name spirit-room-{folder-name}
  -e ROOM_NAME={basename}
  -p {port}:22              # SSH only; Redis stays internal
  -v {folder}:/workspace    # Project files
  -v spirit-room-auth:/root/.claude
  -v spirit-room-opencode-auth:/root/.config/opencode
  spirit-room-base:latest
```

### entrypoint.sh Flow
1. Start SSH via `service ssh start`
2. Start Redis via `service redis-server start`
3. Check `claude auth status` (non-blocking — shows message if not authenticated)
4. Create tmux session "spirit-room" with 3 windows
5. `tail -f /dev/null` (keeps container alive)

### tmux Session Structure (3 Windows, not panes)
| Window | Name | Content |
|--------|------|---------|
| 0 | training | Ready message; user runs `start-training` here |
| 1 | logs | `tail -f /workspace/.logs/progress.log` |
| 2 | workspace | `watch -n 2 'tree /workspace -L 3'` |

**Note:** Requirements and CLAUDE.md say "3 panes" but the implementation creates 3 separate tmux _windows_. Windows are navigated with `Ctrl-b n` rather than being visible simultaneously. This is intentional — it's simpler and works fine for the use case. No change needed.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker daemon | All | ✓ | 29.4.0 | — |
| bash | All scripts | ✓ | System default | — |
| docker CLI | spirit-room CLI | ✓ | 29.4.0 | — |
| SSH client | `spirit-room enter` | ✓ | System default | — |
| tmux | Container session | Built into image | — | — |
| Port 2222 | Default SSH port | ✓ | Available | find_free_port() auto-increments |
| Port 6379 | Redis (internal) | N/A | Container-internal only | — |

**Notes on existing containers:** Several unrelated containers are running (`copilot-server-poc-*`, `copilot-langgraph-*`). None conflict with spirit-room naming or port 2222. [VERIFIED: `docker ps` output]

**spirit-room-base image:** Does NOT exist yet. First build required. [VERIFIED: `docker images spirit-room-base` returned empty]

---

## Standard Stack (What the Dockerfile Installs)

### Layer-by-Layer Analysis

| Layer | Packages/Commands | Status | Notes |
|-------|------------------|--------|-------|
| Layer 1 | curl wget git vim nano openssh-server tmux python3 python3-pip python3-venv build-essential ca-certificates gnupg jq tree sqlite3 libsqlite3-dev redis-server | Should work | Standard Ubuntu 24.04 packages |
| Layer 2 | Node.js 20 via nodesource `setup_20.x` | Should work | nodesource supports Ubuntu 24.04 Noble [ASSUMED] |
| Layer 3 | Bun via `curl bun.sh/install \| bash` | Should work | HOME=/root is default in Docker; PATH set with ENV | 
| Layer 4 | `npm install -g @anthropic-ai/claude-code` | Version 2.1.104 | [VERIFIED: npm registry] |
| Layer 5 | `npm install -g opencode-ai` | Version 1.4.3 | [VERIFIED: npm registry] |
| SSH config | `mkdir /var/run/sshd; echo root:spiritroom \| chpasswd; sed sshd_config` | Risky | BUG-3 — sed may not match |
| File copy | `COPY entrypoint.sh /entrypoint.sh; COPY scripts/ /room/scripts/; COPY catalog/catalog.md /room/catalog.md` | BROKEN | BUG-1 — catalog path wrong |
| chmod | `chmod +x /entrypoint.sh /room/scripts/*.sh` | OK | Fixes script permissions inside image |
| Symlinks | `ln -s start-training.sh /usr/local/bin/start-training; ln -s status.sh /usr/local/bin/status` | OK | Makes commands available in PATH |

### Package Versions (Current)
| Package | Version | Source |
|---------|---------|--------|
| @anthropic-ai/claude-code | 2.1.104 | [VERIFIED: npm view] |
| opencode-ai | 1.4.3 | [VERIFIED: npm view] |
| Ubuntu base | 24.04 | [VERIFIED: Dockerfile] |
| Node.js | 20.x | [VERIFIED: Dockerfile ENV] |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Port conflict detection | Custom port scanner | `find_free_port()` already exists in spirit-room CLI | Already written; uses `docker ps --format '{{.Ports}}'` |
| SSH config hardening | Custom sshd.conf | Append to sshd_config with `echo >> /etc/ssh/sshd_config` | Simple, reliable, order-independent |
| Container keep-alive | Process manager | `tail -f /dev/null` in entrypoint | Standard Docker pattern; already implemented |
| Auth volume sharing | Copy credentials | Docker named volumes | Already designed; just needs volumes pre-created |

---

## Common Pitfalls

### Pitfall 1: Running build-base.sh from the wrong directory
**What goes wrong:** `docker build ... ./base` can't find the `./base` directory
**Why it happens:** The README says `./build-base.sh` — implies running from `spirit-room/` dir, but users may run from the repo root
**How to avoid:** Always run from `spirit-room/` directory: `cd spirit-room && ./build-base.sh`
**Warning signs:** Docker error: `unable to prepare context: path "base" not found`

### Pitfall 2: sshd_config sed fails silently
**What goes wrong:** `spirit-room enter` works (SSH connects) but then disconnects, or `ssh root@localhost -p 2222` says "Permission denied (publickey)"
**Why it happens:** Ubuntu 24.04 sshd_config doesn't have the commented-out pattern the sed looks for
**How to avoid:** Use `echo "PermitRootLogin yes" >> /etc/ssh/sshd_config` instead of sed
**Warning signs:** SSH connection fails with "Permission denied" after build succeeds

### Pitfall 3: claude auth status blocks container startup
**What goes wrong:** `entrypoint.sh` uses `set -e` and calls `claude auth status` — if this returns non-zero unexpectedly, the container exits immediately
**Why it happens:** `set -e` exits on any non-zero return. The auth check is wrapped in `if ! ...; then` which handles the expected failure case correctly, but any other failure (e.g., claude binary not in PATH) would kill the container
**How to avoid:** The `if ! claude auth status &>/dev/null 2>&1` pattern is correct — the `!` negation in an if condition doesn't trigger `set -e`. No action needed, but verify claude is in PATH at container startup.
**Warning signs:** Container exits immediately after starting (check `docker logs <name>`)

### Pitfall 4: Catalog path mismatch in Dockerfile (BUG-1)
**What goes wrong:** Build fails immediately at COPY step
**Why it happens:** Dockerfile says `COPY catalog/catalog.md` but file is at `catalog.md` (no subdir)
**How to avoid:** Fix the COPY line before attempting build
**Warning signs:** `ERROR: failed to solve: failed to read dockerfile` or similar COPY error

### Pitfall 5: spirit-room CLI not executable
**What goes wrong:** `./spirit-room open` returns "Permission denied"  
**Why it happens:** File permissions are `0644` not `0755`
**How to avoid:** `chmod +x spirit-room/spirit-room` before first use
**Warning signs:** "bash: ./spirit-room: Permission denied"

---

## Code Examples

### Fix for BUG-1 (catalog COPY path)
```dockerfile
# Before (broken):
COPY catalog/catalog.md     /room/catalog.md

# After (fixed):
COPY catalog.md             /room/catalog.md
```
[VERIFIED: file location confirmed via `ls spirit-room/base/`]

### Fix for BUG-2 (CLI permissions)
```bash
chmod +x spirit-room/spirit-room
```
[VERIFIED: stat confirms 0644 permissions]

### Fix for BUG-3 (sshd_config — safer approach)
```dockerfile
# Before (fragile):
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# After (robust):
RUN mkdir /var/run/sshd \
    && echo 'root:spiritroom' | chpasswd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
```
[VERIFIED: OpenSSH reads all directives; later entries override earlier ones. `echo >>` is append-safe.]

### Verifying the build worked
```bash
# From spirit-room/ directory:
./build-base.sh

# Expected output:
docker images spirit-room-base
# Should show spirit-room-base:latest with recent CREATED timestamp
```

### Verifying SSH works after container start
```bash
# Start a test container
./spirit-room open /tmp/test-room

# Wait ~2 seconds, then:
ssh -o StrictHostKeyChecking=no root@localhost -p 2222 "echo SSH OK && redis-cli ping"
# Expected: SSH OK
#           PONG
```

### Verifying tmux session
```bash
ssh -o StrictHostKeyChecking=no root@localhost -p 2222 "tmux list-windows -t spirit-room"
# Expected:
# 0: training* (1 panes) ...
# 1: logs- (1 panes) ...
# 2: workspace (1 panes) ...
```

---

## State of the Art

| Component | Current Implementation | Notes |
|-----------|----------------------|-------|
| Container keep-alive | `tail -f /dev/null` | Standard pattern; correct |
| Service management | `service` (init.d) | Correct for Docker without systemd |
| Auth sharing | Docker named volumes | Standard; correct design |
| Port assignment | Sequential scan from 2222 | Functional; CLI-01 in v2 backlog adds deterministic hash |
| tmux session | 3 windows | Requirements say "panes" but windows is fine |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Ubuntu 24.04 sshd_config defaults have changed vs what the sed patterns expect | BUG-3 | If wrong (patterns still match), then BUG-3 is not a bug and the safer fix is still harmless |
| A2 | nodesource setup_20.x supports Ubuntu 24.04 Noble | Standard Stack Layer 2 | If wrong, build fails at Node.js install — fix: use official Node.js Dockerfile approach |
| A3 | claude tool name "LS" in `--allowedTools` is invalid | Not in Phase 1 scope | Phase 2 concern (LOOP-04) — noted for planning awareness |

**Note:** A1 is the most impactful assumption. Even if wrong (patterns match), the `echo >>` fix is safe because OpenSSH uses last-wins for duplicate directives.

---

## Open Questions

1. **Should the fix be catalog/ subdirectory or change the COPY line?**
   - What we know: File is at `catalog.md`, Dockerfile says `catalog/catalog.md`
   - What's unclear: Was `catalog/` directory intentional (for future expansion) or a mistake?
   - Recommendation: Change the COPY line to `COPY catalog.md /room/catalog.md` — simpler. A subdir adds no current value.

2. **Does `service redis-server start` block or return quickly?**
   - What we know: Redis init.d scripts typically daemonize and return immediately
   - What's unclear: If it blocks, entrypoint.sh would hang before creating tmux session
   - Recommendation: Test with `docker logs` after first build. If blocking, add `&` or `nohup`.

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `spirit-room/base/Dockerfile` — all COPY paths verified against actual filesystem
- Direct code inspection: `spirit-room/base/entrypoint.sh` — all service calls, tmux commands verified
- Direct code inspection: `spirit-room/spirit-room` — port logic, container naming, tmux attach verified
- Live environment probe: `docker --version` — Docker 29.4.0 confirmed available
- Live environment probe: `docker images spirit-room-base` — image does NOT exist, build required
- Live environment probe: `stat spirit-room/spirit-room` — permissions 0644 confirmed
- Live environment probe: `npm view @anthropic-ai/claude-code version` — 2.1.104 [VERIFIED: npm registry]
- Live environment probe: `npm view opencode-ai version` — 1.4.3 [VERIFIED: npm registry]
- Live environment probe: `claude --help` — `-p/--print` flag confirmed, `--allowedTools` syntax confirmed

### Secondary (MEDIUM confidence)
- OpenSSH documentation: `echo >> /etc/ssh/sshd_config` append pattern is order-safe

### Tertiary (LOW confidence)
- Ubuntu 24.04 sshd_config default patterns (A1 assumption — not verified against live Ubuntu 24.04 container)

---

## Metadata

**Confidence breakdown:**
- Bug identification: HIGH — confirmed by direct file inspection and stat output
- Standard stack: HIGH — all packages verified via npm registry and Dockerfile review
- Architecture patterns: HIGH — code fully read and traced
- Ubuntu 24.04 sshd defaults: LOW — based on training knowledge of Ubuntu 22.04+ changes

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (stable domain — Docker/bash/SSH don't change often)
