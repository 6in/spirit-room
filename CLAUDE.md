# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 応答言語

**日本語で応答すること。** ユーザーへのすべての返答は日本語で行う。コード、コマンド、ファイルパスはそのまま英語で記載してよい。

## Project Overview

**精神と時の部屋 (Spirit Room)** — a Docker-based AI training sandbox inspired by Dragon Ball Z. It lets AI agents (Claude Code or opencode) autonomously implement framework POCs inside isolated containers, without manual setup. Users work with "Mr. Popo" (an AI hiring manager in `spirit-room-manager/`) to define a learning mission, which launches a Docker room where the agent runs a 2-phase training loop.

## Repository Structure

```
spirit-room/              # Core infrastructure
├── spirit-room           # Host CLI (bash) — open/enter/list/close/logs/auth
├── build-base.sh         # Builds the base Docker image
└── base/
    ├── Dockerfile        # Ubuntu 24.04 + Node.js 20 + Bun + Claude Code + opencode + SSH
    ├── entrypoint.sh     # Container startup: SSH + Redis + tmux 3-pane layout
    └── scripts/
        ├── start-training.sh     # 2-phase training loop (PREPARE → TRAINING)
        ├── status.sh             # Progress inspection inside container
        └── MISSION.md.template   # Template for POC specification

spirit-room-manager/      # Mr. Popo AI manager
├── CLAUDE.md             # Instructs Claude to act as Mr. Popo
├── HANDOVER.md           # Implementation status, design decisions, next steps
└── skills/MR_POPO.md     # Hiring workflow: interview → MISSION.md → launch
```

## Host CLI Commands

```bash
./spirit-room/spirit-room open   [folder]   # Launch new training room (auto-ports)
./spirit-room/spirit-room enter  [folder]   # SSH + tmux attach to active room
./spirit-room/spirit-room list              # Show all running rooms
./spirit-room/spirit-room close  [folder]   # Stop + remove container (keeps workspace)
./spirit-room/spirit-room logs   [folder]   # Tail progress.log from host
./spirit-room/spirit-room auth              # One-time Claude Code auth (shared volume)
```

## Building the Base Image

```bash
cd spirit-room
./build-base.sh              # Tags as spirit-room-base:latest
./build-base.sh v1.2.0       # Custom tag
```

Rebuild is required when: Claude Code/opencode CLI versions change, new system packages added, or `entrypoint.sh`/`start-training.sh` change. MISSION.md and catalog.md changes do NOT require a rebuild.

## Inside the Container

```bash
start-training              # Runs Phase 1 (PREPARE) then Phase 2 (TRAINING) with Claude
start-training opencode     # Same but with opencode engine
status                      # Shows MISSION, workspace tree, recent logs, auth status
```

## Architecture: How It Works

1. **Mr. Popo** (spirit-room-manager) interviews the user (3 questions: framework, goal, constraints), then generates `MISSION.md` in the project folder.
2. **Host CLI** `spirit-room open` launches a Docker container with:
   - Project folder → `/workspace` (read-write mount)
   - Auth credentials → shared named Docker volumes (persists across all rooms)
   - SSH port → auto-assigned starting at 2222
3. **entrypoint.sh** starts SSH, Redis, and a tmux session with 3 panes: training, log tail, workspace watch.
4. **start-training.sh** runs the 2-phase loop:
   - **PHASE 1 (PREPARE)**: Agent reads `catalog.md` + `MISSION.md` → installs dependencies → creates `/workspace/.prepared`
   - **PHASE 2 (TRAINING)**: Agent implements the POC, iterates until it creates `/workspace/.done`
   - Both flags make the loop idempotent (safe to restart)
5. Logs written to `/workspace/.logs/progress.log`.

## Catalog Priority

Agents load documentation from:
```
/workspace/catalog.md   (project-specific, if present)
    ↓ fallback
/room/catalog.md        (default bundled in image)
```

Override by placing a `catalog.md` in the project folder before running `spirit-room open`.

## Container Layout

| Path | Contents |
|------|---------|
| `/workspace/` | Shared mount — project files, MISSION.md, outputs |
| `/room/` | Read-only — scripts and default catalog from image |
| `/logs/` | Symlink target for progress.log |
| `/root/.claude` | Shared auth volume for Claude Code |

## Mr. Popo Workflow (spirit-room-manager)

When working inside `spirit-room-manager/`, the active Claude instance acts as Mr. Popo:
1. Conduct 3-step interview (framework, learning goal, constraints)
2. Generate `MISSION.md` using `base/scripts/MISSION.md.template`
3. Run `spirit-room open [folder]` to launch the room
4. Report: folder path, container name, SSH entry command, monitoring info

Room naming convention: `[framework]-[goal-abbrev]-[poc]` (e.g., `langgraph-subgraph-poc`).

## Implementation Status (from HANDOVER.md)

- **Complete**: Host CLI, Dockerfile, entrypoint, 2-phase training loop, status command, auth sharing, Mr. Popo hiring skill
- **Pending**: Monitoring Web UI (`spirit-room monitor`) — planned with Bun + SSE + docker.sock, not yet implemented

<!-- GSD:project-start source:PROJECT.md -->
## Project

**精神と時の部屋**

DockerコンテナをAI修行の場として使い、AIエージェント（Claude Code / opencode）が自律的にフレームワークのPOCを実装するサンドボックス環境。Mr.ポポ（管理AI）がユーザーにヒアリングしてMISSION.mdを生成し、部屋を起動する。AIが繰り返し「準備 → 実装」フェーズを回し、人手なしにPOCを完成させる。

**Core Value:** Mr.ポポにフレームワーク名と目的を伝えたら、Claude Codeが自律的にPOCを実装して動くところまで完成させる。

### Constraints

- **Tech Stack**: bash + Docker — Node.js/Python等は追加しない。コアはシェルスクリプトのみ
- **Simplicity**: 実装前に大量のファイルを作らない。動いてから育てる
- **Naming**: Dragon Ball世界観（Mr.ポポ、精神と時の部屋）を守る
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Bash - Container orchestration, CLI commands, training loop control
- Shell scripting - All operational scripts and startup routines
- Python3 - Available for scripting and testing inside containers
- Node.js/JavaScript - Available for scripting and tooling
## Runtime
- Ubuntu 24.04 LTS - Base container OS
- Docker - Container runtime platform
- Node.js 20.x - JavaScript/npm runtime
- Bun - JavaScript runtime and package manager
- Python3 - Scripting runtime
- npm - Node.js package management
- pip - Python package management
- Bun - Alternative JavaScript runtime with integrated package management
## Frameworks
- Docker - Container orchestration and isolation
- Claude Code CLI (`@anthropic-ai/claude-code`) - AI code generation and manipulation
- opencode CLI (`opencode-ai`) - Multi-provider AI coding
- tmux - Terminal multiplexer for session management
- OpenSSH Server - SSH access to containers
## Key Dependencies
- `@anthropic-ai/claude-code` [global npm] - Primary autonomous agent for POC implementation
- `opencode-ai` [global npm] - Alternative agent engine
- Redis - In-memory data structure store
- SQLite3 - Embedded relational database
- Git - Version control
- curl/wget - HTTP utilities
- jq - JSON processor
## Configuration
- Docker named volumes for auth credential sharing:
- Docker host port binding: Auto-assigned from port 2222 upward for SSH access
- Environment variable `ROOM_NAME` passed to containers at launch
- `Dockerfile` at `spirit-room/base/Dockerfile` - Image definition
- `build-base.sh` at `spirit-room/build-base.sh` - Rebuild automation script
- Build required when: Claude/opencode versions change, system packages added, or `entrypoint.sh`/`start-training.sh` logic changes
- `entrypoint.sh` at `spirit-room/base/entrypoint.sh` - Container initialization
- `start-training.sh` at `spirit-room/base/scripts/start-training.sh` - 2-phase training orchestration
- `status.sh` at `spirit-room/base/scripts/status.sh` - Progress inspection
## Platform Requirements
- Docker daemon running on host
- Bash shell
- SSH client (for remote container access)
- Sudo access (for CLI installation to `/usr/local/bin`)
- Free ports starting from 2222 (SSH port mapping)
- Ubuntu 24.04 base OS
- 2+ GB RAM per active container
- /workspace mount point for project files
- Shared Docker volumes for authentication persistence
- Port 22/SSH exposed from container to host via dynamic port mapping
- No external internet access required (all tools pre-installed in image)
- Internal Redis on localhost:6379 for inter-process communication
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Project Type
## Naming Patterns
- Executable scripts: lowercase with hyphens, no extension (e.g., `spirit-room`, `start-training`, `status`)
- Markdown documentation: UPPERCASE with `.md` extension (e.g., `MISSION.md.template`, `README.md`, `CLAUDE.md`)
- Shell scripts with extension: lowercase with `.sh` (e.g., `build-base.sh`, `entrypoint.sh`)
- Configuration files: `Dockerfile` (standard Docker convention)
- Documentation: Lowercase with `.md` (e.g., `catalog.md`, `README.md`)
- Bash functions: lowercase with underscores (e.g., `folder_to_name()`, `find_free_port()`, `cmd_open()`)
- Command names: use `cmd_` prefix to organize main command handlers (see `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` lines 50-160)
- Private functions: include leading underscore if internal-only (convention not strongly enforced in this project)
- Environment variables: UPPERCASE (e.g., `ROOM_NAME`, `BASE_IMAGE`, `AUTH_VOLUME`)
- Local variables: lowercase (e.g., `folder`, `port`, `name`)
- Constants in bash: UPPERCASE at top of script (e.g., `LOG_DIR="/workspace/.logs"`)
- Array/list variables: UPPERCASE plural (e.g., `AUTH_VOLUME`, `OPENCODE_AUTH_VOLUME`)
- Container names: lowercase with hyphens, prefix `spirit-room-` (e.g., `spirit-room-langgraph-poc`)
- Docker volumes: lowercase with hyphens (e.g., `spirit-room-auth`, `spirit-room-opencode-auth`)
- Service paths: under `/workspace/`, `/room/`, `/logs/`
## Code Style
- No external formatter enforced (bash linter not present)
- 4-space indentation for bash (observed in `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` and shell scripts)
- No trailing whitespace
- Braces on same line (e.g., `cmd_open() {` line 50)
- Use `set -e` at top of scripts to exit on error (seen in `build-base.sh` line 5, `start-training.sh` line 1, `entrypoint.sh` line 2)
- Use `#!/bin/bash` shebang consistently
- Quote all variable expansions: `"$variable"` not `$variable` (seen throughout `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`)
- Use `[ ... ]` for basic tests, `[[ ... ]]` for complex conditions
- Prefer `local` for function-scoped variables (see `find_free_port()` at line 41)
- Use `echo` with prefixes `[INFO]`, `[ERROR]` for user-facing messages
- Examples from `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`:
- Use `tee -a "$LOG_FILE"` to write to both stdout and logs (see `start-training.sh` lines 22, 27-29)
## Error Handling
- Exit on error: `set -e` at script start (all scripts use this)
- Error messages: use `[ERROR]` prefix and direct user to fix (example: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` lines 100-101)
- Return codes: rely on standard bash exit codes (0 = success, non-zero = failure)
- Conditional execution: use `||` and `&&` for short circuits
- Use loops with flag-based state (see `/home/parallels/workspaces/spirit-room-full/spirit-room/base/scripts/start-training.sh` lines 37-54):
## Comments
- Comments in Japanese and English mixed (project uses Japanese UI)
- Use `# ──` for section separators (common in this project, see `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` lines 33, 40, 49)
- Comment above complex logic (e.g., port assignment logic at line 41-46)
- Document non-obvious bash patterns
## Function Design
- Keep functions under 50 lines typically
- Single responsibility: each `cmd_*` function handles one CLI command
- Examples: `cmd_open()` (lines 50-90), `cmd_enter()` (lines 93-110), `cmd_list()` (lines 113-119)
- Use positional arguments: `"${1:-default}"` for optional with default
- Example: `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` line 35: `local folder="${1:-$(pwd)}"`
- Sanitize paths with `realpath` before using (line 36, 52, 95)
- Functions either:
- Use `return` to exit early from functions
- Use `exit N` only for script-level fatal errors
- Use `|| true` to suppress errors when recovery is expected (line 72)
## Module Design
- Define helper functions at top (lines 34-47 in `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room`)
- Define command functions (lines 50-150)
- Main dispatch at bottom: `case` statement (lines 153-161)
- Use environment variables for cross-container communication (e.g., `ROOM_NAME` passed to container at line 78)
- Docker volumes for auth credential sharing (lines 81-82)
- Mounted directories for workspace sharing (line 80)
- Source shell files: `source ./path/to/script.sh` (not used in this project)
- Include templates: `$(cat $FILE)` to inline template contents (see `start-training.sh` lines 41-49)
## Dockerfile Conventions
- Layer organization by dependency (see `/home/parallels/workspaces/spirit-room-full/spirit-room/base/Dockerfile` lines 8-34)
- Each conceptual group in one RUN to minimize layers
- Comments separate layers: `# ── レイヤーN: 説明 ────`
- Avoid interactive commands in RUN
- Clean package manager cache: `&& rm -rf /var/lib/apt/lists/*` (lines 18, 23)
- Set labels for metadata: `LABEL maintainer=`, `LABEL description=` (lines 2-3)
## Configuration Management
- Use `ENV` for image-level (e.g., line 5-6: `DEBIAN_FRONTEND=noninteractive`, `NODE_VERSION=20`)
- Pass `-e` at `docker run` for container-level (e.g., `/home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room` line 78)
- Document required vars in comments (see `catalog.md` and `MISSION.md.template`)
## API/Service Communication
- Use `docker ps --format '{{...}}'` for parseable output (line 56, 115)
- Use `docker ps --filter` to target specific containers (line 116)
- Use pipes for command composition (line 43, 118)
- Disable host key checking for automation: `-o StrictHostKeyChecking=no` (line 106)
- Use password auth with preset password in container (see Dockerfile line 37)
- Tunnel through tmux for session reattachment (line 109)
## Japanese/English Bilingual Convention
- English: script names, function names, technical comments, documentation structure
- Japanese: user messages, tmux window names, section headers in comments
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Folder-as-container model: Project directory becomes Docker container environment
- Two-phase sequential training (PREPARE → TRAINING) with bash loop control
- Idempotent execution via flag files (`.prepared`, `.done`)
- Shared authentication volumes for credential reuse across containers
- Catalog-driven agent instrumentation (MISSION.md + catalog.md)
## Layers
- Purpose: CLI interface for container lifecycle management
- Location: `spirit-room` (bash CLI script)
- Contains: Container creation, port assignment, SSH/tmux management
- Depends on: Docker daemon, bash, docker CLI
- Used by: End users launching and managing training rooms
- Purpose: Interview users and generate training missions
- Location: `spirit-room-manager/` (Claude instance with MR_POPO skill)
- Contains: Hiring workflow, MISSION.md generation, room launch coordination
- Depends on: Orchestration layer CLI, file I/O
- Used by: Users defining training objectives
- Purpose: Execution environment for AI agent training
- Location: `base/Dockerfile` with entrypoint and script ecosystem
- Contains: Ubuntu 24.04 base, Node.js 20, Bun, Claude Code, opencode, SSH, Redis, tmux
- Depends on: Docker daemon, base image build
- Used by: Training agents during PREPARE and TRAINING phases
- Purpose: Execute two-phase AI training loop with resume capability
- Location: `base/scripts/start-training.sh`
- Contains: PREPARE phase (dependency installation), TRAINING phase (implementation)
- Depends on: Container runtime, catalog.md, MISSION.md
- Used by: Agents invoked via `start-training [engine]` command
- Purpose: Terminal multiplexing and log aggregation
- Location: `base/entrypoint.sh` (tmux configuration)
- Contains: tmux 3-pane session (training, logs, workspace), SSH daemon
- Depends on: tmux, SSH server
- Used by: Users entering containers and monitoring progress
## Data Flow
- **Persistent state**: `/workspace/` (shared mount, survives container lifecycle)
- **Ephemeral state**: In-container logs at `/workspace/.logs/progress.log`
- **Flags for idempotency**: `/workspace/.prepared`, `/workspace/.done`
- **Credentials**: Named Docker volumes `spirit-room-auth`, `spirit-room-opencode-auth`
## Key Abstractions
- Purpose: Defines training objective, completion criteria, constraints
- Examples: `base/scripts/MISSION.md.template`, user-generated instances in project folders
- Pattern: Markdown document with structured sections (目的, 完了条件, 実装スコープ, 制約)
- Purpose: Available tools and their capabilities for agent selection
- Examples: `base/catalog.md` (default), overridable per project at `/workspace/catalog.md`
- Pattern: Markdown listing with tool names, use cases, invocation syntax
- Purpose: Deterministic mapping from folder to container identity
- Pattern: `spirit-room-{folder-name}` with lowercase and sanitization
- Used in: Docker naming, SSH host identification, tmux session naming
- Purpose: Support multiple AI agent backends with single command
- Examples: `claude` (default), `opencode` (fallback)
- Pattern: `start-training [engine]` switches implementation at line 26 in `start-training.sh`
## Entry Points
- Location: `spirit-room` (bash script)
- Triggers: User invokes one of: `open`, `enter`, `list`, `close`, `logs`, `auth`
- Responsibilities: Parse arguments, Docker lifecycle, SSH/port management, log tailing
- Location: `base/entrypoint.sh`
- Triggers: Docker run (container creation)
- Responsibilities: Start SSH/Redis, create tmux session, display status messages
- Location: `base/scripts/start-training.sh`
- Triggers: User or automated scheduler runs `start-training [engine]`
- Responsibilities: Validate MISSION.md, execute PREPARE phase, execute TRAINING phase
- Location: `spirit-room-manager/CLAUDE.md`
- Triggers: Claude instance starts in `spirit-room-manager/` directory
- Responsibilities: Read MR_POPO.md, conduct user interview, generate MISSION.md, launch room
## Error Handling
- **Missing MISSION.md**: `start-training.sh` exits with error message and template suggestion (line 16-19)
- **Phase incomplete**: 3-second sleep, then retry (lines 38, 51, 80-82)
- **Authentication missing**: `entrypoint.sh` displays login instructions without blocking startup (lines 19-28)
- **Port conflict**: `find_free_port()` increments port until available (lines 41-47)
- **Container already running**: `spirit-room open` detects existing container and suggests `enter` instead (lines 56-60)
## Cross-Cutting Concerns
- Centralized: `/workspace/.logs/progress.log`
- Written by: Training scripts via `tee -a` (appends to file and stdout)
- Monitored by: tmux "logs" pane via `tail -f`
- Accessible from host via: `spirit-room logs [folder]`
- MISSION.md required before training starts
- `.prepared` flag mandatory before TRAINING phase executes
- Folder path normalization and container name sanitization in CLI
- Shared volumes persist credentials across rooms
- One-time setup via `spirit-room auth` (Device Flow for Claude Code)
- Separate volumes for Claude Code and opencode
- Each room is independent Docker container with own `/workspace` mount
- Shared credentials via named volumes (not copied per container)
- SSH port auto-assignment prevents conflicts (start: 2222, increment as needed)
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

## Git ブランチ戦略

**フェーズ実行・TODO・QUICK タスクは必ずブランチを作成して作業すること。**

- 作業開始時に `git checkout -b <branch-name>` でブランチを作成する
  - フェーズ作業: `phase/01-infrastructure` のような名前
  - TODO/QUICK: `fix/xxx` や `chore/xxx` のような名前
- ブランチ上ではこまめにコミットしてよい
- main へマージするときは **squash merge** で細かいコミットを1つにまとめる:
  ```bash
  git checkout main
  git merge --squash <branch-name>
  git commit -m "feat(phase-01): ..."
  git branch -d <branch-name>
  ```

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
