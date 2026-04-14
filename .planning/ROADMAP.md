# Roadmap: 精神と時の部屋

## Overview

The project exists as mostly-written bash + Docker code that has never been run end-to-end. Three natural delivery boundaries emerge from the requirements: first make the container build and start cleanly, then make Claude auth and the training loop function correctly inside it, then validate the full Mr. Popo → POC flow from one end to the other.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Infrastructure** - Docker image builds and container starts with all core services running
- [ ] **Phase 2: Auth & Training Loop** - Claude Code auth works inside the container and the two-phase training loop executes correctly
- [ ] **Phase 3: End-to-End Flow** - Mr. Popo hearing → MISSION.md → spirit-room open → POC complete runs without manual intervention

## Phase Details

### Phase 1: Infrastructure
**Goal**: The Docker image builds cleanly and a container starts with SSH, tmux, and Redis all functional
**Depends on**: Nothing (first phase)
**Requirements**: BUILD-01, BUILD-02, RUN-01, RUN-02, RUN-03, RUN-04
**Success Criteria** (what must be TRUE):
  1. `./build-base.sh` completes without errors and `spirit-room-base:latest` exists in `docker images`
  2. `spirit-room open [folder]` starts a container and SSH connection succeeds
  3. Redis is running inside the container after `spirit-room open` (no manual start needed)
  4. tmux session shows three panes: training, logs, workspace
  5. `spirit-room enter [folder]` attaches to the tmux session
**Plans**: 2 plans
  - [ ] 01-01-PLAN.md — Fix Dockerfile/CLI bugs and build spirit-room-base image (Wave 1)
  - [ ] 01-02-PLAN.md — Verify container runtime: open, SSH, Redis, tmux, enter (Wave 2)

### Phase 2: Auth & Training Loop
**Goal**: Claude Code can authenticate inside a container and `start-training.sh` drives the full PHASE1 → PHASE2 loop to completion
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, LOOP-01, LOOP-02, LOOP-03, LOOP-04
**Success Criteria** (what must be TRUE):
  1. `spirit-room auth` completes Claude Code authentication inside a running container
  2. The `spirit-room-auth` Docker volume is shared and reused across multiple rooms without re-authenticating
  3. `start-training.sh` runs PHASE1, installs deps, and creates the `.prepared` flag
  4. `start-training.sh` runs PHASE2, executes the MISSION, and creates the `.done` flag
  5. Restarting a container that has `.prepared` resumes at PHASE2 (does not repeat PHASE1)
**Plans**: 3 plans
  - [x] 02-01-PLAN.md — Fix run_claude --dangerously-skip-permissions and rebuild base image (Wave 1)
  - [x] 02-02-PLAN.md — Verify spirit-room auth and shared auth volume across rooms (Wave 2)
  - [ ] 02-03-PLAN.md — Verify full PHASE1->PHASE2 training loop and resume behavior (Wave 3)

### Phase 3: End-to-End Flow
**Goal**: A user can tell Mr. Popo a framework name and purpose and Claude Code autonomously delivers a working POC without manual intervention
**Depends on**: Phase 2
**Requirements**: E2E-01, E2E-02, E2E-03
**Success Criteria** (what must be TRUE):
  1. Running `spirit-room-manager` starts Mr. Popo, completes the hearing, and writes MISSION.md
  2. Using that MISSION.md with `spirit-room open` starts the container and the training loop launches automatically
  3. Claude Code completes the POC implementation and the `.done` flag is created
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Infrastructure | 0/TBD | Not started | - |
| 2. Auth & Training Loop | 2/3 | In Progress|  |
| 3. End-to-End Flow | 0/TBD | Not started | - |
