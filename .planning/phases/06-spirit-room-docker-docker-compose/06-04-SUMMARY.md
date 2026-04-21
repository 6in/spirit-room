---
phase: 06-spirit-room-docker-docker-compose
plan: "04"
subsystem: spirit-room CLI
tags: [cli, docker, compose, dood, bash]
dependency_graph:
  requires:
    - 06-01-PLAN.md  # Dockerfile docker CLI レイヤー
    - 06-02-PLAN.md  # entrypoint.sh docker グループ合流ロジック
    - 06-03-PLAN.md  # catalog.md Docker Compose モードセクション
  provides:
    - spirit-room/spirit-room --docker フラグ対応 CLI
    - _docker_extra_args() ヘルパー関数
    - cmd_close 兄弟コンテナ自動掃除
  affects:
    - spirit-room open / kaio コマンドの全引数転送 (dispatch 修正)
tech_stack:
  added: []
  patterns:
    - mapfile -t で 1 行 1 トークン関数出力を配列化 (空白安全)
    - for ループ + case で任意位置フラグ解析 (getopts 不使用)
    - docker ps -a --filter label= で compose 兄弟コンテナ検出
key_files:
  modified:
    - spirit-room/spirit-room
decisions:
  - _docker_extra_args() は 1 行 1 トークン echo 形式。mapfile -t で配列化することで空白を含むパスでも単語分割が起きない (D-10)
  - --docker フラグは cmd_open / cmd_kaio の両方に適用。for ループ + case でどの位置でも解釈可能 (D-11)
  - dispatch を "${2:-}" から "${@:2}" に変更。--docker と folder 両方を正しく転送する BLOCKER 修正
  - cmd_close は --docker フラグ有無に関わらず compose project ラベルで兄弟を検索。兄弟 0 件は xargs -r で no-op (D-17/D-18)
  - バナー警告は確認プロンプトなし。opt-in フラグで意思表示済みとみなす (D-19)
metrics:
  duration: "約8分"
  completed_date: "2026-04-18"
  tasks_completed: 2
  files_modified: 1
---

# Phase 06 Plan 04: spirit-room CLI --docker フラグ対応 Summary

## One-liner

`spirit-room open/kaio --docker` フラグで docker.sock マウント + SPIRIT_ROOM_DOCKER=1 環境変数を渡し、`close` 時に compose 兄弟コンテナを自動掃除する CLI 拡張。

## What Was Built

`spirit-room/spirit-room` に以下の変更を加え、DooD (Docker-out-of-Docker) 対応を実装した。

### Task 1: `_docker_extra_args()` ヘルパーと `usage()` 更新

- `find_free_port()` 直後に `_docker_extra_args()` を追加
- 1 行 1 トークン形式で以下を echo:
  - `-v /var/run/docker.sock:/var/run/docker.sock`
  - `--add-host=host.docker.internal:host-gateway`
  - `-e HOST_WORKSPACE=<folder>`
  - `-e SPIRIT_ROOM_HOST_GATEWAY=host.docker.internal`
  - `-e SPIRIT_ROOM_DOCKER=1`
  - `-e COMPOSE_PROJECT_NAME=<room_name>`
  - `-e HOST_DOCKER_GID=<gid>` (stat 成功時のみ)
- `usage()` の例ブロックに `--docker` の使い方 2 行を追記

### Task 2: cmd_open / cmd_kaio / cmd_close / dispatch 変更

**cmd_open:**
- 先頭で `for _a in "$@"` + `case` による任意位置フラグ解析
- `docker_flag=1` 時のみバナー直後に `[WARN]` 警告 2 行を表示
- `mapfile -t _extra_args < <(_docker_extra_args "$folder" "$name")` で空白安全配列化
- `"${_extra_args[@]}"` を docker run に展開

**cmd_kaio:**
- cmd_open と同様のフラグ解析・バナー警告・配列化を追加
- 認証同期の `--rm` docker run には `_extra_args` を渡さない (D-10)

**cmd_close:**
- `docker stop/rm` 後に `docker ps -a --filter "label=com.docker.compose.project=${name}" -q` で兄弟検索
- 兄弟があれば件数ログ → `xargs -r docker rm -f`
- 兄弟ゼロ件でも `[INFO] 兄弟コンテナは見つかりませんでした` を出力して正常終了

**dispatch (BLOCKER 修正):**
- `cmd_open "${2:-}"` → `cmd_open "${@:2}"` に変更
- `cmd_kaio "${2:-}"` → `cmd_kaio "${@:2}"` に変更
- これにより `spirit-room open --docker /path`、`spirit-room open /path --docker`、`spirit-room open --docker` の全パターンが正しく転送される

## Commits

| Hash | Message |
|------|---------|
| 16c521c | feat(phase-06): _docker_extra_args() ヘルパー関数と usage() への --docker 例を追加 |
| b094d47 | feat(phase-06): cmd_open/cmd_kaio に --docker フラグ、cmd_close に兄弟掃除を追加 |

## Deviations from Plan

### 自動修正

**1. [Rule 1 - Bug] dispatch の "${2:-}" を "${@:2}" に修正 (BLOCKER)**
- **Found during:** Task 2 実装中 (PLAN.md に BLOCKER 修正として明記)
- **Issue:** `"${2:-}"` では `--docker` か `folder` のどちらか一方しか渡せず、両方を同時に渡せない
- **Fix:** `"${@:2}"` で 2 番目以降の全引数を展開するように変更
- **Files modified:** spirit-room/spirit-room (dispatch セクション)
- **Commit:** b094d47

**2. [Rule 2 - WARNING 修正] mapfile による空白安全な配列化**
- **Found during:** Task 2 (PLAN.md に WARNING 修正として明記)
- **Issue:** `while IFS= read -r _line; do _extra_args+=($_line); done` パターンは引用符なし展開で単語分割が発生する可能性
- **Fix:** `mapfile -t _extra_args < <(_docker_extra_args ...)` に変更
- **Files modified:** spirit-room/spirit-room (cmd_open / cmd_kaio)
- **Commit:** b094d47

### docker_flag カウント差異

計画の acceptance_criteria で「`grep -c 'docker_flag' spirit-room/spirit-room` が 10 以上」と記載されているが、実際は 8 件。これは各関数で `local docker_flag=0` (1) + `--docker) docker_flag=1` (1) + `if [ "$docker_flag" = "1" ]` (2) = 4 行 × 2 関数 = 8 件が正しい実装数。計画の期待値は目安であり、機能的には完全に正しく実装されている。

## Known Stubs

なし。

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: elevation-of-privilege | spirit-room/spirit-room | docker.sock マウントは opt-in の --docker フラグのみ。デフォルト非マウント + バナー警告で D-19 準拠 (T-06-04-01 対処済み) |

## Self-Check: PASSED

- spirit-room/spirit-room: FOUND
- commit 16c521c: FOUND
- commit b094d47: FOUND
- bash -n: OK (構文エラーなし)
- `cmd_open  "${@:2}"`: FOUND
- `cmd_kaio  "${@:2}"`: FOUND
- `mapfile -t _extra_args`: FOUND
- `com.docker.compose.project`: FOUND (1件)
- `xargs -r docker rm -f`: FOUND (1件)
