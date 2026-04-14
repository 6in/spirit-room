# Codebase Concerns

**Analysis Date:** 2026-04-13

## Security Concerns

**Hardcoded SSH Root Password:**
- Issue: Root SSH password `spiritroom` is hardcoded in the Dockerfile and documented in README
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/Dockerfile` (line 37), `/home/parallels/workspaces/spirit-room-full/spirit-room/README.md` (line 88), `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` (line 88)
- Impact: Any user on the host who can reach the container's SSH port can gain root access with a known password. This is a critical vulnerability if containers are exposed to untrusted networks.
- Mitigation: Currently mitigated by design (containers are local, SSH ports are host-only), but extremely fragile if deployment model changes.
- Recommendation: Use SSH key authentication instead of passwords. Generate ephemeral keys per container or use docker socket authentication.

**Unrestricted Docker Socket Access Planned:**
- Issue: Future monitoring UI feature (`spirit-room monitor`) will require `docker.sock` access to monitor running containers
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room-manager/HANDOVER.md` (line 41)
- Impact: Mounting docker.sock exposes container escape risk. Any compromise inside the monitoring service can allow container breakout or management of other rooms.
- Recommendation: Implement strict filtering via docker-socket-proxy or use Docker API with read-only scope and explicit filtering.

**Shell Injection Risk in CLI:**
- Issue: `find_free_port()` and container name derivation use unquoted variables and sed patterns
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` (lines 34-47)
- Impact: Folder paths with special characters (e.g., `$(rm -rf /)/folder`) could bypass sanitization in `folder_to_name`. The sed replace `sed 's/[^a-z0-9-]/-/g'` is present but not applied to all uses.
- Current state: Mitigated by `realpath` conversion and basename extraction, but brittle for unusual characters.
- Recommendation: Use stricter validation. Enforce folder name patterns rather than relying on sed cleanup.

**No Validation of MISSION.md Syntax:**
- Issue: `start-training.sh` assumes MISSION.md is well-formed but doesn't validate structure
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (lines 16-20)
- Impact: Malformed MISSION.md will cause confusing errors deep in the Claude prompt loop, not at validation time.
- Recommendation: Add schema validation or YAML/TOML parsing before entering training phases.

## Reliability & Operational Issues

**Port Assignment Race Condition:**
- Issue: `find_free_port()` scans Docker ports at call time but doesn't guarantee exclusivity before `docker run` executes
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` (lines 41-47, 54)
- Impact: Under heavy concurrent `spirit-room open` calls, two rooms could attempt the same port, causing the second to fail with a cryptic Docker error.
- Probability: Low in typical single-user workflows, higher in automation/CI environments.
- Recommendation: Use deterministic port allocation (hash-based) as noted in HANDOVER.md line 43, or implement file-based locking.

**Infinite Retry Loop Without Backoff:**
- Issue: `start-training.sh` retries phases with fixed 3-second sleep, no exponential backoff or max attempts
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (lines 37-54, 61-83)
- Impact: If Claude Code crashes or hangs repeatedly, the loop will consume resources indefinitely. Container restart just resets the loop, allowing infinite retry.
- Current mitigation: `.prepared` and `.done` flags make restarts idempotent, but failure modes aren't properly handled.
- Recommendation: Add max retry count, exponential backoff, and explicit failure states (`.failed` flag) to prevent runaway containers.

**No Timeout on Claude Execution:**
- Issue: `run_claude()` invokes Claude with no execution timeout
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (lines 24-30)
- Impact: If Claude hangs (network issues, tool deadlock), the training phase blocks indefinitely. The 3-second retry only applies after completion detection, not during execution.
- Recommendation: Wrap Claude calls with `timeout` command with reasonable limits (e.g., 1200 seconds per phase attempt).

**Catalog.md Path Resolution Ambiguity:**
- Issue: Catalog priority is `/workspace/catalog.md` > `/room/catalog.md`, but the fallback is silent
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (lines 10-11), `/home/parallels/workspaces/spirit-room-full/spirit-room/base/entrypoint.sh` (lines 30-35)
- Impact: If a user intends to use a customized catalog but it has a typo or wrong permissions, they silently fall back to defaults without warning.
- Recommendation: Add explicit logging of which catalog is being used and warn if custom catalog fails to load.

**Log Directory Must Be Created Before Use:**
- Issue: `.logs/` directory is created inside `start-training.sh`, not in entrypoint
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (line 13)
- Impact: If logs directory creation fails, progress.log won't exist and the training loop will still proceed, losing diagnostic information.
- Recommendation: Create `.logs/` in entrypoint.sh to ensure it always exists.

**No Container Resource Limits:**
- Issue: Docker containers launched by `spirit-room open` have no CPU, memory, or disk quotas
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` (lines 75-83)
- Impact: A runaway training loop (e.g., infinite recursion in Python code) can exhaust host memory and crash the system.
- Recommendation: Add `--memory`, `--cpus`, and storage limits to docker run command.

## Architecture & Design Concerns

**Missing Monitoring Web UI Implementation:**
- Issue: `spirit-room monitor` commands are documented but not implemented
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room-manager/HANDOVER.md` (lines 41-42), `/home/parallels/workspaces/spirit-room-full/spirit-room-manager/CLAUDE.md` (line 12)
- Impact: Users cannot monitor multiple rooms simultaneously. Logs are tail-only via CLI. Web UI is promised but absent.
- Current state: Feature is explicitly listed as "未実装" in HANDOVER.
- Recommendation: Implement Bun + SSE server with docker.sock integration (as designed), but defer until port determinism and docker socket security are addressed.

**Catalog.md Redundant in Both Dockerfile and Image:**
- Issue: Catalog is copied into Docker image (`COPY catalog/catalog.md /room/catalog.md` in Dockerfile), but the directory path is unclear
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/Dockerfile` (line 47)
- Impact: `catalog/catalog.md` source path may not exist if directory structure is `base/catalog.md` instead. Build silently fails or copies wrong file.
- Current state: Likely working but brittle path reference.
- Recommendation: Use explicit path `base/catalog.md` in COPY command.

**No Cleanup of Failed Containers:**
- Issue: If `docker run` fails during `cmd_open()`, no cleanup occurs
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` (lines 75-83)
- Impact: Partially created containers or volumes may be left behind on failure, consuming space.
- Recommendation: Add `trap` cleanup handler or use `docker run --rm` with proper error handling.

**SSH Keys vs Passwords in entrypoint:**
- Issue: entrypoint.sh attempts to detect Claude auth status using stderr redirect but doesn't handle all failure modes
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/entrypoint.sh` (line 19)
- Impact: Claude auth check could fail silently or with unclear error messages. The double redirect `2>&1 2>&1` is redundant.
- Recommendation: Improve error handling and auth status detection logic.

**No Version Pinning for Global npm Packages:**
- Issue: Dockerfile installs claude-code and opencode-ai with `-g` but no version constraints
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/Dockerfile` (lines 30, 33)
- Impact: Different base image builds may have incompatible tool versions. New major releases could break existing workflows.
- Recommendation: Pin versions: `npm install -g @anthropic-ai/claude-code@2.x` or use lockfile.

## Test Coverage Gaps

**No Tests for CLI Commands:**
- Issue: `spirit-room` CLI script has no unit or integration tests
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`
- What's not tested: Port assignment collision, container name sanitization, volume mounting, auth flow
- Risk: Critical path for users. Subtle bugs in folder-to-name mapping or port allocation could go unnoticed until production.
- Priority: High

**No Tests for Training Loop:**
- Issue: `start-training.sh` has no test cases for retry logic, flag handling, or Claude integration
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh`
- What's not tested: .prepared/.done flag behavior on restart, catalog fallback, MISSION validation
- Risk: Core training loop is bash logic with no safety net. Flag corruption could hang containers indefinitely.
- Priority: High

**No Integration Tests for entrypoint:**
- Issue: Container startup sequence (SSH, Redis, tmux, auth check) has no validation
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/entrypoint.sh`
- What's not tested: Service startup timing, catalog precedence, tmux session setup
- Risk: Container might appear running but services could fail silently.
- Priority: Medium

**No MISSION.md Schema Validation:**
- Issue: No tests verify MISSION.md structure or completeness
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room-manager/skills/MR_POPO.md` (lines 38-67)
- What's not tested: Required sections, completion condition syntax, constraint validation
- Risk: Invalid MISSION.md will cause confusing Claude prompt failures later.
- Priority: Medium

## Documentation & Clarity Issues

**Ambiguous MISSION Template Sections:**
- Issue: Template uses placeholder text that may confuse users
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/MISSION.md.template` (lines 1-54)
- Impact: Sections like "背景・学習したいこと" (background/learning goal) are distinct but their relationship to the completion conditions is unclear.
- Recommendation: Add explicit linking between learning goals and completion conditions in template.

**Unclear catalog.md Override Behavior:**
- Issue: Documentation doesn't clarify what happens if a custom catalog.md has incomplete sections
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/README.md` (lines 100-108)
- Impact: Users may think custom catalogs extend defaults, but the entire file is used instead.
- Recommendation: Document merge behavior explicitly or implement actual merging.

**No Error Recovery Documentation:**
- Issue: README and HANDOVER don't document what to do if training fails, container crashes, or phases hang
- Impact: Users have no recovery path and may have to manually clean up containers.
- Recommendation: Add troubleshooting section documenting common failure modes and recovery steps.

## Dependencies at Risk

**Bun Installation via curl:**
- Issue: Bun is installed via `curl -fsSL https://bun.sh/install | bash`
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/Dockerfile` (line 26)
- Risk: Executing untrusted script directly. No checksum verification or fallback.
- Mitigation: Bun is only used in future monitoring UI, not core training.
- Recommendation: Use official package repositories or pin a specific Bun version.

**Claude Code Availability:**
- Issue: Training loop depends on `claude` command being in PATH and authenticated
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (line 27)
- Risk: If Anthropic deprecates or removes Claude Code CLI, all training rooms become non-functional.
- Recommendation: Document fallback to Claude API directly or opencode engine.

## Performance Concerns

**Inefficient Port Scanning:**
- Issue: `find_free_port()` iterates sequentially starting at port 2222, checking all Docker ports each iteration
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` (lines 41-47)
- Impact: With 100+ rooms, port discovery could take minutes. Better to use deterministic hash-based allocation.
- Recommendation: Implement hash-based port allocation as noted in HANDOVER (line 43).

**Catalog Concatenation in Every Prompt:**
- Issue: `start-training.sh` reads and concatenates catalog.md into every Claude prompt without caching
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (lines 41-43, 65-67)
- Impact: Large catalogs will increase token usage and latency. No memoization across retries.
- Recommendation: Cache catalog content as environment variable or file during phase.

**Verbose Logging Without Rotation:**
- Issue: `progress.log` grows unbounded, with no rotation or size limits
- Files: `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` (line 22)
- Impact: Long-running training sessions could create gigabyte-sized logs, slowing disk I/O.
- Recommendation: Implement logrotate or truncate logs after completion.

---

*Concerns audit: 2026-04-13*
