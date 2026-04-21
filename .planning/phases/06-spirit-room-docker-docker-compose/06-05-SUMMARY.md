---
phase: 06-spirit-room-docker-docker-compose
plan: 05
completed: 2026-04-19
status: passed
---

# Plan 06-05 SUMMARY — イメージ再ビルド + E2E 検証

## 実施内容

**Task 1 (auto): 静的検証 + イメージ再ビルド**

- 13 項目の静的検証 (bash -n / grep パターン) 全 OK
- `./build-base.sh` 完走 → `spirit-room-base:latest` 再ビルド
- イメージ内の docker CLI 動作確認: Docker 29.4.0 + Compose v5.1.3

**Task 2 (human-verify blocking): E2E 9 ステップ**

| Step | 内容 | 結果 |
|------|------|------|
| 1 | イメージ内 docker CLI 存在 | ✓ |
| 2 | `--docker` フラグで起動 + バナー警告 | ✓ |
| 3 | 起動ログに `[INFO] docker grp: ...` が出る | ✓ (fallback 分岐) |
| 4 | goku login shell で env (SPIRIT_ROOM_DOCKER / HOST_WORKSPACE / SPIRIT_ROOM_HOST_GATEWAY / COMPOSE_PROJECT_NAME) 全部見える | ✓ (fix 後) |
| 5 | `sudo docker ps` が通る | ✓ |
| 6 | `sudo docker compose up -d` で nginx 起動 + label=spirit-room-test-compose-proj | ✓ (sudoers env_keep fix 後) |
| 7 | `curl host.docker.internal:8181` で HTTP 200 + HTML 取得 | ✓ |
| 8 | `spirit-room close` で部屋 + 兄弟 (nginx) 両方削除 | ✓ (`兄弟コンテナ 1 件を削除しました`) |
| 9 | `--docker` 未指定で非回帰 (env なし / sock なし / close 正常) | ✓ |

**Task 3 (auto): 駆動 todo を completed へ**

- `.planning/todos/pending/2026-04-18-spirit-room-docker-docker-compose.md` → `.planning/todos/completed/` へ移動
- 完了メタデータ追記 (completed / phase / plans)

## E2E 中に発覚したバグと追加修正 (2 件)

検証中に Plan 06-04 と Plan 06-02 の隠れた不具合が見つかり、同フェーズ内で修正:

### Bug 1: `_docker_extra_args()` の `echo "-e"` / `echo "-v"` が消費される

- bash 組み込み `echo` は `-e` / `-v` / `-n` をフラグとして解釈し、何も出力しない
- 結果として `mapfile` 配列に `-e` が欠落し、`docker run` が `invalid reference format` で失敗
- **Fix:** `echo` を `printf '%s\n'` に置換 (commit a228bef)

### Bug 2: tmux/SSH で goku に入ると --docker env が見えない + sudo で剥がれる

- entrypoint.sh の `su - goku -c "bash -s"` は login shell で env リセット → SPIRIT_ROOM_DOCKER などが tmux 起動時に消える
- sudo 実行時も env が落ちるため、`sudo docker compose up` で COMPOSE_PROJECT_NAME が剥がれて sibling label が cwd 由来になり close 時の掃除が効かない
- **Fix (2 箇所, commit 6c9a1e9):**
  - `~/.profile` に `export SPIRIT_ROOM_DOCKER / HOST_WORKSPACE / SPIRIT_ROOM_HOST_GATEWAY / COMPOSE_PROJECT_NAME` を追記 (CLAUDE_CONFIG_DIR と同じパターン)
  - `/etc/sudoers.d/goku` に `Defaults env_keep += "COMPOSE_PROJECT_NAME SPIRIT_ROOM_DOCKER HOST_WORKSPACE SPIRIT_ROOM_HOST_GATEWAY HOST_DOCKER_GID"` を追加

## 変更ファイル

- `spirit-room/base/Dockerfile` (Plan 01)
- `spirit-room/base/entrypoint.sh` (Plan 02 + Plan 05 E2E fixes)
- `spirit-room/base/catalog.md` (Plan 03)
- `spirit-room/spirit-room` (Plan 04 + Plan 05 E2E fix)
- `.planning/todos/completed/2026-04-18-spirit-room-docker-docker-compose.md` (移動)

## Phase 6 must_haves 達成状況

- ✓ spirit-room-base:latest に docker CLI が常時同梱
- ✓ `--docker` 起動で `/var/run/docker.sock` マウント + `host.docker.internal` 到達
- ✓ env (SPIRIT_ROOM_DOCKER / HOST_WORKSPACE / SPIRIT_ROOM_HOST_GATEWAY / COMPOSE_PROJECT_NAME / HOST_DOCKER_GID) が tmux/goku shell まで伝搬
- ✓ docker グループ合流 or sudo fallback のいずれかで `docker ps` が通る
- ✓ `docker compose up` で兄弟コンテナが起動し、label=`com.docker.compose.project=<room_name>` で識別可能
- ✓ `spirit-room close` で部屋 + 全兄弟コンテナを自動削除
- ✓ `--docker` 未指定時の完全非回帰 (env なし / sock なし)

## Next

Phase 6 は完了。ROADMAP / STATE を更新して main へ squash merge する。
