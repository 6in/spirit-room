# Technology Stack

**Analysis Date:** 2026-04-13

## Languages

**Primary:**
- Bash - Container orchestration, CLI commands, training loop control
- Shell scripting - All operational scripts and startup routines

**Secondary:**
- Python3 - Available for scripting and testing inside containers
- Node.js/JavaScript - Available for scripting and tooling

## Runtime

**Environment:**
- Ubuntu 24.04 LTS - Base container OS
- Docker - Container runtime platform
- Node.js 20.x - JavaScript/npm runtime
- Bun - JavaScript runtime and package manager
- Python3 - Scripting runtime

**Package Managers:**
- npm - Node.js package management
- pip - Python package management
- Bun - Alternative JavaScript runtime with integrated package management

## Frameworks

**Core Infrastructure:**
- Docker - Container orchestration and isolation
  - Location: Dockerfile at `spirit-room/base/Dockerfile`
  - Used for: Creating isolated training environments

**AI/Agent Tools:**
- Claude Code CLI (`@anthropic-ai/claude-code`) - AI code generation and manipulation
  - Installed globally via npm in base image
  - Primary training engine alongside opencode
  
- opencode CLI (`opencode-ai`) - Multi-provider AI coding
  - Installed globally via npm in base image
  - Alternative training engine for multi-provider support

**Development/Monitoring:**
- tmux - Terminal multiplexer for session management
  - Location: `spirit-room/base/entrypoint.sh` - 3-pane session setup
  - Used for: parallel process management inside containers

- OpenSSH Server - SSH access to containers
  - Enabled in Dockerfile
  - Used for: Remote container access and CLI tooling

## Key Dependencies

**Critical:**
- `@anthropic-ai/claude-code` [global npm] - Primary autonomous agent for POC implementation
  - Why it matters: Core training engine that reads MISSION.md and executes PREPARE/TRAINING phases
  
- `opencode-ai` [global npm] - Alternative agent engine
  - Why it matters: Provides multi-provider fallback for extended capabilities

**Infrastructure:**
- Redis - In-memory data structure store
  - Installed: base image, auto-started in entrypoint.sh
  - Used for: Caching and inter-process communication within containers

- SQLite3 - Embedded relational database
  - Installed: `sqlite3` and `libsqlite3-dev` packages in base image
  - Used for: Light POC data storage without external DB

- Git - Version control
  - Pre-installed in base image
  - Used for: Project repository management

- curl/wget - HTTP utilities
  - Pre-installed in base image
  - Used for: External API testing and downloads

- jq - JSON processor
  - Pre-installed in base image
  - Used for: JSON manipulation in scripts

## Configuration

**Environment:**
- Docker named volumes for auth credential sharing:
  - `spirit-room-auth` - Shared Claude Code credentials across all rooms
  - `spirit-room-opencode-auth` - Shared opencode credentials across all rooms
- Docker host port binding: Auto-assigned from port 2222 upward for SSH access
- Environment variable `ROOM_NAME` passed to containers at launch

**Build:**
- `Dockerfile` at `spirit-room/base/Dockerfile` - Image definition
- `build-base.sh` at `spirit-room/build-base.sh` - Rebuild automation script
- Build required when: Claude/opencode versions change, system packages added, or `entrypoint.sh`/`start-training.sh` logic changes

**Startup/Runtime:**
- `entrypoint.sh` at `spirit-room/base/entrypoint.sh` - Container initialization
- `start-training.sh` at `spirit-room/base/scripts/start-training.sh` - 2-phase training orchestration
- `status.sh` at `spirit-room/base/scripts/status.sh` - Progress inspection

## Platform Requirements

**Development:**
- Docker daemon running on host
- Bash shell
- SSH client (for remote container access)
- Sudo access (for CLI installation to `/usr/local/bin`)
- Free ports starting from 2222 (SSH port mapping)

**Production (Container):**
- Ubuntu 24.04 base OS
- 2+ GB RAM per active container
- /workspace mount point for project files
- Shared Docker volumes for authentication persistence

**Network:**
- Port 22/SSH exposed from container to host via dynamic port mapping
- No external internet access required (all tools pre-installed in image)
- Internal Redis on localhost:6379 for inter-process communication

---

*Stack analysis: 2026-04-13*
