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
  - [x] 02-03-PLAN.md — Verify full PHASE1->PHASE2 training loop and resume behavior (Wave 3)

### Phase 3: End-to-End Flow
**Goal**: A user can tell Mr. Popo a framework name and purpose and Claude Code autonomously delivers a working POC without manual intervention
**Depends on**: Phase 2
**Requirements**: E2E-01, E2E-02, E2E-03
**Success Criteria** (what must be TRUE):
  1. Running `spirit-room-manager` starts Mr. Popo, completes the hearing, and writes MISSION.md
  2. Using that MISSION.md with `spirit-room open` starts the container and the training loop launches automatically
  3. Claude Code completes the POC implementation and the `.done` flag is created
**Plans**: 2 plans
  - [ ] 03-01-PLAN.md — Fix infrastructure: install CLI, entrypoint auto-start, catalog pip flag, rebuild (Wave 1)
  - [ ] 03-02-PLAN.md — Verify Mr. Popo E2E: hearing -> MISSION.md -> auto-training -> .done (Wave 2)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Infrastructure | 0/TBD | Not started | - |
| 2. Auth & Training Loop | 2/3 | In Progress|  |
| 3. End-to-End Flow | 0/2 | Not started | - |

### Phase 4: 界王星モード: GSD駆動の本格開発トレーニング部屋 (CLAUDE_CONFIG_DIR 切替 + 認証 symlink + /gsd-autonomous 非対話チェーン)

**Goal:** 界王星モード追加 — `spirit-room kaio` で起動する部屋が CLAUDE_CONFIG_DIR で GSD を隔離インストールし、共有認証を symlink で引き継ぎ、Mr.ポポのモード選択経由で `/gsd-new-project` → `/gsd-autonomous` を非対話実行して段階開発をタグリリースまで完走する
**Requirements**: KAIO-ENTRYPOINT-01, KAIO-AUTH-SYMLINK-01, KAIO-CLI-01, KAIO-MISSION-TEMPLATE-01, KAIO-TRAINING-LOOP-01, KAIO-MRPOPO-MODE-01, KAIO-E2E-01
**Depends on:** Phase 3
**Plans:** 5 plans
  - [x] 04-01-PLAN.md — entrypoint.sh に CLAUDE_CONFIG_DIR 分岐と credentials symlink を追加 (Wave 1)
  - [x] 04-02-PLAN.md — spirit-room CLI に kaio サブコマンドを追加 (Wave 1)
  - [x] 04-03-PLAN.md — KAIO-MISSION.md.template を新規作成 (Wave 1)
  - [x] 04-04-PLAN.md — start-training-kaio.sh + entrypoint tmux 分岐 + Mr.ポポ Step 0 モード選択 (Wave 2)
  - [x] 04-05-PLAN.md — ベース再ビルド + Mr.ポポ経由 E2E 検証 (Wave 3)

### Phase 5: コンテナ内に goku ユーザーを作成しホスト UID/GID と一致させる — root 実行による /workspace の所有権問題を解消し、コンテナ終了後にホスト側で sudo chown が不要になる状態を実現する。entrypoint.sh で HOST_UID/HOST_GID を受け取り、goku ユーザーをランタイム作成 + NOPASSWD sudo 付与。spirit-room CLI の docker run に -e HOST_UID/HOST_GID を追加し、SSH/tmux も goku で起動。共有認証ボリューム (spirit-room-auth, spirit-room-opencode-auth) の所有権マイグレーションと kaio モード対応を含む

**Goal:** コンテナ内の実行ユーザーを root から goku (ホスト UID/GID 一致) に切り替え、/workspace 成果物がホスト側で自ユーザー所有として直接扱える状態を達成する — sudo chown 不要。Phase 4 の kaio / 既存の通常モード両方で動く。
**Requirements**: PHASE5-DOCKERFILE-SSH-01, PHASE5-ENTRYPOINT-GOKU-01, PHASE5-ENTRYPOINT-FALLBACK-01, PHASE5-ENTRYPOINT-SUDOERS-01, PHASE5-ENTRYPOINT-CHOWN-01, PHASE5-ENTRYPOINT-KAIO-SYMLINK-01, PHASE5-ENTRYPOINT-GITCONFIG-01, PHASE5-ENTRYPOINT-TMUX-GOKU-01, PHASE5-ENTRYPOINT-PID1-ROOT-01, PHASE5-CLI-OPEN-UID-01, PHASE5-CLI-KAIO-UID-01, PHASE5-CLI-KAIO-SYNC-CHOWN-01, PHASE5-CLI-ENTER-GOKU-01, NON_REGRESSION-BUILD-01, NON_REGRESSION-AUTH-01, NON_REGRESSION-LOOP-01, NON_REGRESSION-PHASE4-KAIO-01, NON_REGRESSION-CLI-01
**Depends on:** Phase 4
**Plans:** 3 plans

Plans:
- [x] 05-01-PLAN.md — Dockerfile の SSH 設定を PermitRootLogin no に変更し sudo パッケージを確認 (Wave 1)
- [x] 05-02-PLAN.md — entrypoint.sh に HOST_UID 受取 / goku 冪等作成 / chown / kaio symlink chown / goku HOME git config / tmux を su - goku -c でラップ (Wave 2)
- [x] 05-03-PLAN.md — spirit-room CLI の cmd_open / cmd_kaio / cmd_kaio --rm / cmd_enter に HOST_UID 渡しと goku SSH を反映 (Wave 2)

### Phase 6: spirit-room に --docker フラグを追加して Docker Compose ベースのプロダクトを修行対象にできるようにする

**Goal:** `spirit-room open --docker [folder]` で起動した部屋から、Claude が `docker compose up` でホスト上の兄弟コンテナとしてプロダクトを起動・操作できる状態を達成する。DooD (socket マウント) 方式で軽量実装、opt-in のためデフォルト挙動は変えない。compose のボリュームパス解釈問題とサービスへのネットワーク到達問題を catalog.md の指示と環境変数で解決する。
**Depends on:** Phase 5
**Plans:** TBD

実装スコープ:
- **CLI (`spirit-room/spirit-room`)**: `cmd_open` に `--docker` フラグを追加。フラグ指定時は docker run に以下を追加 — (1) `-v /var/run/docker.sock:/var/run/docker.sock`、(2) `--add-host=host.docker.internal:host-gateway`、(3) `-e HOST_WORKSPACE=<ホスト絶対パス>`、(4) `-e SPIRIT_ROOM_HOST_GATEWAY=host.docker.internal`。`cmd_kaio` も同様に対応するか要検討。
- **Dockerfile (`spirit-room/base/Dockerfile`)**: docker CLI + compose plugin を追加 (`curl -fsSL https://get.docker.com | sh`、dockerd は起動しない)。goku ユーザーを `docker` グループに追加して sock にアクセス可能にする。
- **Catalog (`spirit-room/base/catalog.md`)**: compose 使用時のボリューム記法 (`${HOST_WORKSPACE}` を使う)、サービスアクセス方法 (`host.docker.internal:PORT`)、セキュリティ注意 (ホスト root 相当の権限) を追記。
- **セキュリティ**: socket マウントはホスト root 相当なので opt-in (`--docker` フラグ必須) を堅持。デフォルトは従来通り安全側。

参照: `.planning/todos/pending/2026-04-18-spirit-room-docker-docker-compose.md`
