# Coding Conventions

**Analysis Date:** 2026-04-13

## Project Type

This is a **bash-based infrastructure project** with no TypeScript, JavaScript, or traditional unit testing frameworks. All code is shell scripts, Dockerfiles, and documentation.

## Naming Patterns

**Files:**
- Executable scripts: lowercase with hyphens, no extension (e.g., `spirit-room`, `start-training`, `status`)
- Markdown documentation: UPPERCASE with `.md` extension (e.g., `MISSION.md.template`, `README.md`, `CLAUDE.md`)
- Shell scripts with extension: lowercase with `.sh` (e.g., `build-base.sh`, `entrypoint.sh`)
- Configuration files: `Dockerfile` (standard Docker convention)
- Documentation: Lowercase with `.md` (e.g., `catalog.md`, `README.md`)

**Functions:**
- Bash functions: lowercase with underscores (e.g., `folder_to_name()`, `find_free_port()`, `cmd_open()`)
- Command names: use `cmd_` prefix to organize main command handlers (see `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` lines 50-160)
- Private functions: include leading underscore if internal-only (convention not strongly enforced in this project)

**Variables:**
- Environment variables: UPPERCASE (e.g., `ROOM_NAME`, `BASE_IMAGE`, `AUTH_VOLUME`)
- Local variables: lowercase (e.g., `folder`, `port`, `name`)
- Constants in bash: UPPERCASE at top of script (e.g., `LOG_DIR="/workspace/.logs"`)
- Array/list variables: UPPERCASE plural (e.g., `AUTH_VOLUME`, `OPENCODE_AUTH_VOLUME`)

**Containers/Services:**
- Container names: lowercase with hyphens, prefix `spirit-room-` (e.g., `spirit-room-langgraph-poc`)
- Docker volumes: lowercase with hyphens (e.g., `spirit-room-auth`, `spirit-room-opencode-auth`)
- Service paths: under `/workspace/`, `/room/`, `/logs/`

## Code Style

**Formatting:**
- No external formatter enforced (bash linter not present)
- 4-space indentation for bash (observed in `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` and shell scripts)
- No trailing whitespace
- Braces on same line (e.g., `cmd_open() {` line 50)

**Shell Conventions:**
- Use `set -e` at top of scripts to exit on error (seen in `build-base.sh` line 5, `start-training.sh` line 1, `entrypoint.sh` line 2)
- Use `#!/bin/bash` shebang consistently
- Quote all variable expansions: `"$variable"` not `$variable` (seen throughout `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`)
- Use `[ ... ]` for basic tests, `[[ ... ]]` for complex conditions
- Prefer `local` for function-scoped variables (see `find_free_port()` at line 41)

**Logging:**
- Use `echo` with prefixes `[INFO]`, `[ERROR]` for user-facing messages
- Examples from `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`:
  - Line 57: `echo "[INFO] 部屋 '$name' はすでに起動中です"`
  - Line 101: `echo "[ERROR] 部屋 '$name' は起動していません"`
- Use `tee -a "$LOG_FILE"` to write to both stdout and logs (see `start-training.sh` lines 22, 27-29)

## Error Handling

**Patterns:**
- Exit on error: `set -e` at script start (all scripts use this)
- Error messages: use `[ERROR]` prefix and direct user to fix (example: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` lines 100-101)
- Return codes: rely on standard bash exit codes (0 = success, non-zero = failure)
- Conditional execution: use `||` and `&&` for short circuits
  - Example from `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` line 72: `docker volume create "$AUTH_VOLUME" > /dev/null 2>&1 || true`
  - This prevents failure if volume already exists

**Error Recovery:**
- Use loops with flag-based state (see `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` lines 37-54):
  - Check for completion flag first: `[ -f "$PREPARED_FLAG" ] && { ... break; }`
  - Retry on failure: `sleep 3` then loop (line 53)
  - This pattern ensures idempotent operations safe for restart

## Comments

**When to Comment:**
- Comments in Japanese and English mixed (project uses Japanese UI)
- Use `# ──` for section separators (common in this project, see `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` lines 33, 40, 49)
- Comment above complex logic (e.g., port assignment logic at line 41-46)
- Document non-obvious bash patterns

**Example from codebase:**
```bash
# ── フォルダパス → コンテナ名 ────────────────────────────────
folder_to_name() {
    local folder="${1:-$(pwd)}"
    folder=$(realpath "$folder")
    echo "spirit-room-$(basename $folder)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g'
}
```

**No JSDoc/TSDoc:** Not applicable (bash project)

## Function Design

**Size:**
- Keep functions under 50 lines typically
- Single responsibility: each `cmd_*` function handles one CLI command
- Examples: `cmd_open()` (lines 50-90), `cmd_enter()` (lines 93-110), `cmd_list()` (lines 113-119)

**Parameters:**
- Use positional arguments: `"${1:-default}"` for optional with default
- Example: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` line 35: `local folder="${1:-$(pwd)}"`
- Sanitize paths with `realpath` before using (line 36, 52, 95)

**Return Values:**
- Functions either:
  - Echo a value (e.g., `echo $port` at line 46)
  - Execute command and rely on exit status (e.g., `docker ps` checks at line 56)
  - Set global/exported variables (less common, prefer echoing)

**Early Returns:**
- Use `return` to exit early from functions
- Use `exit N` only for script-level fatal errors
- Use `|| true` to suppress errors when recovery is expected (line 72)

## Module Design

**Script Organization:**
- Define helper functions at top (lines 34-47 in `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`)
- Define command functions (lines 50-150)
- Main dispatch at bottom: `case` statement (lines 153-161)

**Exports:**
- Use environment variables for cross-container communication (e.g., `ROOM_NAME` passed to container at line 78)
- Docker volumes for auth credential sharing (lines 81-82)
- Mounted directories for workspace sharing (line 80)

**Import Pattern:**
- Source shell files: `source ./path/to/script.sh` (not used in this project)
- Include templates: `$(cat $FILE)` to inline template contents (see `start-training.sh` lines 41-49)

## Dockerfile Conventions

**Structure:**
- Layer organization by dependency (see `/home/parallels/workspaces/spirit-room-full/spirit-room/base/Dockerfile` lines 8-34)
- Each conceptual group in one RUN to minimize layers
- Comments separate layers: `# ── レイヤーN: 説明 ────`

**Commands:**
- Avoid interactive commands in RUN
- Clean package manager cache: `&& rm -rf /var/lib/apt/lists/*` (lines 18, 23)
- Set labels for metadata: `LABEL maintainer=`, `LABEL description=` (lines 2-3)

## Configuration Management

**Environment Variables:**
- Use `ENV` for image-level (e.g., line 5-6: `DEBIAN_FRONTEND=noninteractive`, `NODE_VERSION=20`)
- Pass `-e` at `docker run` for container-level (e.g., `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` line 78)
- Document required vars in comments (see `catalog.md` and `MISSION.md.template`)

**No .env files enforced:** This is intentional for portability (auth via volumes instead)

## API/Service Communication

**Docker Commands:**
- Use `docker ps --format '{{...}}'` for parseable output (line 56, 115)
- Use `docker ps --filter` to target specific containers (line 116)
- Use pipes for command composition (line 43, 118)

**SSH:**
- Disable host key checking for automation: `-o StrictHostKeyChecking=no` (line 106)
- Use password auth with preset password in container (see Dockerfile line 37)
- Tunnel through tmux for session reattachment (line 109)

## Japanese/English Bilingual Convention

**Mixed-language output:** Project uses Japanese for user-facing UI but English for technical docs
- English: script names, function names, technical comments, documentation structure
- Japanese: user messages, tmux window names, section headers in comments

Example from `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`:
```bash
# 使い方:  (Japanese comment)
echo "[INFO] 部屋を開きました"  (Japanese user message)
# ── フォルダパス → コンテナ名 ────  (bilingual comment with diagram)
```

---

*Convention analysis: 2026-04-13*
