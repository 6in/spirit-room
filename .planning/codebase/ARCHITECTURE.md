# Architecture

**Analysis Date:** 2026-04-13

## Pattern Overview

**Overall:** Container-based AI training sandbox with two-phase idempotent loop architecture.

**Key Characteristics:**
- Folder-as-container model: Project directory becomes Docker container environment
- Two-phase sequential training (PREPARE → TRAINING) with bash loop control
- Idempotent execution via flag files (`.prepared`, `.done`)
- Shared authentication volumes for credential reuse across containers
- Catalog-driven agent instrumentation (MISSION.md + catalog.md)

## Layers

**Orchestration Layer (Host):**
- Purpose: CLI interface for container lifecycle management
- Location: `spirit-room` (bash CLI script)
- Contains: Container creation, port assignment, SSH/tmux management
- Depends on: Docker daemon, bash, docker CLI
- Used by: End users launching and managing training rooms

**Management Layer (AI Agent):**
- Purpose: Interview users and generate training missions
- Location: `spirit-room-manager/` (Claude instance with MR_POPO skill)
- Contains: Hiring workflow, MISSION.md generation, room launch coordination
- Depends on: Orchestration layer CLI, file I/O
- Used by: Users defining training objectives

**Container Runtime Layer:**
- Purpose: Execution environment for AI agent training
- Location: `base/Dockerfile` with entrypoint and script ecosystem
- Contains: Ubuntu 24.04 base, Node.js 20, Bun, Claude Code, opencode, SSH, Redis, tmux
- Depends on: Docker daemon, base image build
- Used by: Training agents during PREPARE and TRAINING phases

**Training Automation Layer:**
- Purpose: Execute two-phase AI training loop with resume capability
- Location: `base/scripts/start-training.sh`
- Contains: PREPARE phase (dependency installation), TRAINING phase (implementation)
- Depends on: Container runtime, catalog.md, MISSION.md
- Used by: Agents invoked via `start-training [engine]` command

**Session Management Layer:**
- Purpose: Terminal multiplexing and log aggregation
- Location: `base/entrypoint.sh` (tmux configuration)
- Contains: tmux 3-pane session (training, logs, workspace), SSH daemon
- Depends on: tmux, SSH server
- Used by: Users entering containers and monitoring progress

## Data Flow

**Room Lifecycle Flow:**

1. **User initiates** → `spirit-room open [folder]`
2. **CLI validates** → Folder normalization, free port discovery
3. **Container spawns** → Docker run with mounts: `/workspace` (project), auth volumes (persistent)
4. **Entrypoint executes** → SSH/Redis startup, tmux session creation
5. **User enters** → SSH attachment, tmux attach to "training" pane
6. **Training starts** → `start-training` invoked (engine: claude/opencode)

**Training Phase Flow (PREPARE):**

1. **Agent receives** → `catalog.md` (tools available) + `MISSION.md` (task definition)
2. **Agent extracts goals** → Framework, learning objective, completion criteria
3. **Agent installs** → Package installation via pip/npm/apt
4. **Agent signals completion** → Creates `/workspace/.prepared` flag
5. **Loop checks** → Next invocation skips PREPARE (flag exists)

**Training Phase Flow (TRAINING):**

1. **Agent receives** → Same catalog.md + MISSION.md (now in implementation mode)
2. **Agent implements** → Creates code, runs tests, iterates on failures
3. **Agent refines** → Reads error logs, retries with different approaches
4. **Agent signals completion** → Creates `/workspace/.done` flag + README.md
5. **Loop exits** → Process completes, container remains running

**State Management:**

- **Persistent state**: `/workspace/` (shared mount, survives container lifecycle)
- **Ephemeral state**: In-container logs at `/workspace/.logs/progress.log`
- **Flags for idempotency**: `/workspace/.prepared`, `/workspace/.done`
- **Credentials**: Named Docker volumes `spirit-room-auth`, `spirit-room-opencode-auth`

## Key Abstractions

**MISSION.md (Task Contract):**
- Purpose: Defines training objective, completion criteria, constraints
- Examples: `base/scripts/MISSION.md.template`, user-generated instances in project folders
- Pattern: Markdown document with structured sections (目的, 完了条件, 実装スコープ, 制約)

**catalog.md (Tools Menu):**
- Purpose: Available tools and their capabilities for agent selection
- Examples: `base/catalog.md` (default), overridable per project at `/workspace/catalog.md`
- Pattern: Markdown listing with tool names, use cases, invocation syntax

**Container Name Convention:**
- Purpose: Deterministic mapping from folder to container identity
- Pattern: `spirit-room-{folder-name}` with lowercase and sanitization
- Used in: Docker naming, SSH host identification, tmux session naming

**Training Engine Abstraction:**
- Purpose: Support multiple AI agent backends with single command
- Examples: `claude` (default), `opencode` (fallback)
- Pattern: `start-training [engine]` switches implementation at line 26 in `start-training.sh`

## Entry Points

**Host CLI Entry Point:**
- Location: `spirit-room` (bash script)
- Triggers: User invokes one of: `open`, `enter`, `list`, `close`, `logs`, `auth`
- Responsibilities: Parse arguments, Docker lifecycle, SSH/port management, log tailing

**Container Entry Point:**
- Location: `base/entrypoint.sh`
- Triggers: Docker run (container creation)
- Responsibilities: Start SSH/Redis, create tmux session, display status messages

**Training Entry Point (Automated):**
- Location: `base/scripts/start-training.sh`
- Triggers: User or automated scheduler runs `start-training [engine]`
- Responsibilities: Validate MISSION.md, execute PREPARE phase, execute TRAINING phase

**Management AI Entry Point:**
- Location: `spirit-room-manager/CLAUDE.md`
- Triggers: Claude instance starts in `spirit-room-manager/` directory
- Responsibilities: Read MR_POPO.md, conduct user interview, generate MISSION.md, launch room

## Error Handling

**Strategy:** Graceful degradation with flag-based resumption; agent retry loops with backoff.

**Patterns:**
- **Missing MISSION.md**: `start-training.sh` exits with error message and template suggestion (line 16-19)
- **Phase incomplete**: 3-second sleep, then retry (lines 38, 51, 80-82)
- **Authentication missing**: `entrypoint.sh` displays login instructions without blocking startup (lines 19-28)
- **Port conflict**: `find_free_port()` increments port until available (lines 41-47)
- **Container already running**: `spirit-room open` detects existing container and suggests `enter` instead (lines 56-60)

## Cross-Cutting Concerns

**Logging:** 
- Centralized: `/workspace/.logs/progress.log`
- Written by: Training scripts via `tee -a` (appends to file and stdout)
- Monitored by: tmux "logs" pane via `tail -f`
- Accessible from host via: `spirit-room logs [folder]`

**Validation:**
- MISSION.md required before training starts
- `.prepared` flag mandatory before TRAINING phase executes
- Folder path normalization and container name sanitization in CLI

**Authentication:**
- Shared volumes persist credentials across rooms
- One-time setup via `spirit-room auth` (Device Flow for Claude Code)
- Separate volumes for Claude Code and opencode

**Isolation:**
- Each room is independent Docker container with own `/workspace` mount
- Shared credentials via named volumes (not copied per container)
- SSH port auto-assignment prevents conflicts (start: 2222, increment as needed)

---

*Architecture analysis: 2026-04-13*
