---
phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui
plan: 03
subsystem: infra
tags: [bash, docker, cli, ssh, uid-gid, host-integration]

# Dependency graph
requires:
  - phase: 05
    provides: "Plan 01 (Dockerfile PermitRootLogin=no + sudo + gosu) と Plan 02 (entrypoint で goku 作成 + chown + su - goku tmux) と協調して動く"
provides:
  - "spirit-room open / kaio の docker run に HOST_UID / HOST_GID を渡す (entrypoint が goku を作れるようにする)"
  - "spirit-room kaio の docker run --rm 認証同期で credentials.json を HOST_UID:HOST_GID に chown"
  - "spirit-room enter が goku ユーザーで SSH する (root ではなく)"
affects: [phase-06, host-integration, user-docs, HANDOVER]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "docker run の -e env 引数で HOST_UID/HOST_GID をコンテナに伝搬"
    - "docker run --rm -c の中で \\$HOST_UID をバックスラッシュエスケープしてコンテナ内展開にする"

key-files:
  created: []
  modified:
    - spirit-room/spirit-room

key-decisions:
  - "cmd_open / cmd_kaio / cmd_kaio --rm の 3 箇所に -e HOST_UID=\"$(id -u)\" と -e HOST_GID=\"$(id -g)\" を追加 (D-16, D-17)"
  - "cmd_kaio --rm の -c 文字列に chown \\$HOST_UID:\\$HOST_GID /dst/.credentials.json をエスケープ付きで挿入 (D-15, Pattern C3)"
  - "cmd_enter の ssh ユーザーを root → goku に変更 (D-07, D-18)"
  - "cmd_open のヘルプメッセージの ssh root@localhost 表記も goku に統一"
  - "cmd_auth は非変更: entrypoint 側が毎回 chown するので CLI 側は不要 (D-11, Pattern C4)"

patterns-established:
  - "Pattern C1: cmd_open の docker run -d で ROOM_NAME の直後に HOST_UID/HOST_GID を並べる"
  - "Pattern C2: cmd_kaio の docker run -d で CLAUDE_CONFIG_DIR の直後に HOST_UID/HOST_GID を並べる"
  - "Pattern C3: docker run --rm -c の中でコンテナ内展開したい変数は \\$VAR でバックスラッシュエスケープ"
  - "Pattern C5: cmd_enter の SSH ターゲットユーザーを goku@localhost に統一"

requirements-completed:
  - PHASE5-CLI-OPEN-UID-01
  - PHASE5-CLI-KAIO-UID-01
  - PHASE5-CLI-KAIO-SYNC-CHOWN-01
  - PHASE5-CLI-ENTER-GOKU-01
  - NON_REGRESSION-CLI-01

# Metrics
duration: 15min
completed: 2026-04-17
---

# Phase 5 Plan 03: spirit-room CLI goku 対応 Summary

**spirit-room CLI の 3 箇所に HOST_UID/HOST_GID 伝搬、認証同期コンテナに chown 挿入、SSH ユーザーを root → goku に切替 — 4 箇所の最小差分で Plan 01/02 の entrypoint 側 goku 化に必要な入力を供給する**

## Performance

- **Duration:** 約 15 min
- **Started:** 2026-04-17T10:37:00Z (approx)
- **Completed:** 2026-04-17T10:52:00Z
- **Tasks:** 3 auto + 1 checkpoint (parallel worktree: static validation)
- **Files modified:** 1 (`spirit-room/spirit-room`)

## Accomplishments

- `cmd_open` の docker run に `-e HOST_UID="$(id -u)"` と `-e HOST_GID="$(id -g)"` を追加 (ROOM_NAME の直後)
- `cmd_kaio` の docker run に同じ env ペアを追加 (CLAUDE_CONFIG_DIR の直後)
- `cmd_kaio` の docker run --rm (認証同期) に env ペアを追加し、`-c` 文字列に `chown \$HOST_UID:\$HOST_GID /dst/.credentials.json` をエスケープ付きで挿入
- `cmd_enter` の `ssh -t root@localhost` を `ssh -t goku@localhost` に変更
- `cmd_open` のヘルプメッセージ (`echo "  または: ssh root@localhost ..."`) も goku 表記に統一
- `cmd_auth` / `cmd_list` / `cmd_close` / `cmd_logs` / `resolve_running_name` / `usage` / `find_free_port` / `folder_to_name` は完全に非変更 (non-regression)

## Task Commits

Each task was committed atomically:

1. **Task 3.1: cmd_open / cmd_kaio docker run -d に -e HOST_UID/GID 追加** — `e6a4128` (feat)
2. **Task 3.2: cmd_kaio docker run --rm に env + chown 追加** — `cf97b0d` (feat)
3. **Task 3.3: cmd_enter SSH ユーザーを goku に変更 + ヘルプ修正** — `241d4da` (feat)

**Plan metadata:** この SUMMARY のコミットは最後にまとめて作成される (docs: 05-03 complete plan)

## Files Created/Modified

- `spirit-room/spirit-room` — 以下 4 箇所の最小差分:
  - L77-86 (cmd_open): `-e HOST_UID="$(id -u)"` と `-e HOST_GID="$(id -g)"` を ROOM_NAME の直後に 2 行挿入
  - L91 (cmd_open help): `ssh root@localhost` → `ssh goku@localhost`
  - L129-135 (cmd_kaio 認証同期 --rm): env ペア 2 行 + `-c` 内 chown (エスケープ付き) 挿入
  - L141-150 (cmd_kaio 本体): `-e HOST_UID` / `-e HOST_GID` を CLAUDE_CONFIG_DIR の直後に 2 行挿入
  - L192-195 (cmd_enter): `-t root@localhost` → `-t goku@localhost`

## Diff Summary (4 箇所)

### 1. cmd_open (L77-L86)

```diff
     docker run -d \
         --name "$name" \
         --hostname "$name" \
         -e ROOM_NAME="$(basename $folder)" \
+        -e HOST_UID="$(id -u)" \
+        -e HOST_GID="$(id -g)" \
         -p "${port}:22" \
         ...
```

### 2. cmd_open help message

```diff
-    echo "  または: ssh root@localhost -p $port  (パス: spiritroom)"
+    echo "  または: ssh goku@localhost -p $port  (パス: spiritroom)"
```

### 3. cmd_kaio 認証同期 docker run --rm (L129-L135)

```diff
         docker run --rm \
             -v "${AUTH_VOLUME}:/dst" \
             -v "${host_creds}:/src/.credentials.json:ro" \
+            -e HOST_UID="$(id -u)" \
+            -e HOST_GID="$(id -g)" \
             --entrypoint /bin/bash \
             "$BASE_IMAGE" \
-            -c "cp /src/.credentials.json /dst/.credentials.json && chmod 600 /dst/.credentials.json" \
+            -c "cp /src/.credentials.json /dst/.credentials.json && chown \$HOST_UID:\$HOST_GID /dst/.credentials.json && chmod 600 /dst/.credentials.json" \
             > /dev/null 2>&1 || echo "[WARN] 認証情報同期に失敗"
```

### 4. cmd_kaio 本体 docker run -d (L141-L150)

```diff
     docker run -d \
         --name "$name" \
         --hostname "$name" \
         -e ROOM_NAME="$(basename $folder)" \
         -e CLAUDE_CONFIG_DIR=/workspace/.claude-home \
+        -e HOST_UID="$(id -u)" \
+        -e HOST_GID="$(id -g)" \
         -p "${port}:22" \
         ...
```

### 5. cmd_enter SSH (L192-L195)

```diff
     ssh -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null \
-        -t root@localhost -p "$port" \
+        -t goku@localhost -p "$port" \
         "tmux attach -t spirit-room || tmux new-session -s spirit-room"
```

## Must-haves Truth Achievement (goal-backward)

| truth | 結果 | 根拠 |
|-------|------|------|
| spirit-room open 実行時、docker run に -e HOST_UID=$(id -u) -e HOST_GID=$(id -g) が渡される | ✓ | `grep -c '\-e HOST_UID="$(id -u)"'` = 3 のうち 1 件が cmd_open、ROOM_NAME の直後に配置 |
| spirit-room kaio 実行時、docker run (本体) と docker run --rm (認証同期) の両方に -e HOST_UID/-e HOST_GID が渡される | ✓ | 残り 2 件が cmd_kaio 本体と cmd_kaio --rm に配置 (合計 3/3) |
| spirit-room kaio の docker run --rm 内で credentials.json が chown $HOST_UID:$HOST_GID される | ✓ | `-c` 内に `chown \$HOST_UID:\$HOST_GID /dst/.credentials.json` リテラル存在 (ホスト bash ではエスケープされるためコンテナ内で展開) |
| spirit-room enter 実行時、ssh -t goku@localhost で接続する (root ではない) | ✓ | `-t goku@localhost -p "$port"` に書換済み、`-t root@localhost` は完全に消失 |
| tmux session 名 'spirit-room' / ポート探索 / resolve_running_name / cmd_list / cmd_close / cmd_logs / cmd_auth は非回帰 | ✓ | tmux コマンド文字列 / ssh オプション / パスワード表記 / cmd_auth 内 chown 未追加 すべて確認 |

## Static Validation (Task 3.4 checkpoint, parallel worktree mode)

parallel worktree では live Docker 検証は実行不可のため、以下の static check を実施し、すべて PASS:

```
bash -n spirit-room/spirit-room
# => exit 0

grep -c '-e HOST_UID="$(id -u)"' spirit-room/spirit-room  # => 3
grep -c '-e HOST_GID="$(id -g)"' spirit-room/spirit-room  # => 3
grep -F 'chown \$HOST_UID:\$HOST_GID /dst/.credentials.json' spirit-room/spirit-room  # => match
grep -q 'cp /src/.credentials.json /dst/.credentials.json'    # => match
grep -q 'chmod 600 /dst/.credentials.json'                    # => match
grep -q '認証情報同期に失敗'                                   # => match (fallback preserved)
grep -q '-t goku@localhost -p "$port"'                        # => match
! grep -q '-t root@localhost'                                 # => match (removed)
grep -q 'ssh goku@localhost -p $port'                         # => match (help updated)
! grep -q 'ssh root@localhost -p $port'                       # => match (help root removed)
grep -q 'tmux attach -t spirit-room || tmux new-session -s spirit-room'  # => match
grep -q 'StrictHostKeyChecking=no'                            # => match
grep -q 'UserKnownHostsFile=/dev/null'                        # => match
grep -q 'パス: spiritroom'                                    # => match
grep -A15 '^cmd_auth()' spirit-room/spirit-room | grep -c chown  # => 0 (D-11: cmd_auth 非変更)
```

Plan 3.1 / 3.2 / 3.3 の acceptance_criteria に記載されているすべての静的テストをパス。

## Decisions Made

- **エスケープ戦略**: `docker run --rm -c "..."` の文字列ではホスト bash が `$(id -u)` を先に展開して `-e HOST_UID=1000` のように env に渡す。その env 値を**コンテナ内 bash で展開したい** chown の位置では `\$HOST_UID` とバックスラッシュエスケープ。これにより実ファイル上には `chown \$HOST_UID:\$HOST_GID ...` のリテラルが残り、docker が `-c` 文字列を解釈するときは `chown $HOST_UID:$HOST_GID ...` と見えてコンテナ内で展開される。
- **クォート**: 既存パターン `-e ROOM_NAME="$(basename $folder)"` と統一して `-e HOST_UID="$(id -u)"` のように double quote 付きで command substitution を書いた (クォート無しは空入力時の安全性も損なうため採用せず)。
- **chown 位置**: `-c` 文字列内では cp → chown → chmod 600 の順。順不同でも可だが、所有者設定の後にパーミッション最終化するのが自然。
- **cmd_auth は非変更**: D-11 の決定どおり、`cmd_auth` の docker run --rm には chown を追加しない。entrypoint が毎回起動時に認証ボリュームを chown するため CLI 側では冪等性を担保しなくてよい (二重管理回避)。

## Deviations from Plan

None - plan executed exactly as written.

4 タスク (3 auto + 1 checkpoint) すべてを PLAN.md の `<action>` 指示と `<acceptance_criteria>` に従って実行。Rule 1-4 のいずれのトリガーも発火せず。

## Issues Encountered

None. `bash -n` もすべてクリーン、`grep` ベースの acceptance も全パス。

`PreToolUse:Edit` hook が Edit 成功後にも警告を出す (READ-BEFORE-EDIT reminder) が、セッション冒頭で Read 済みのため実害なし。編集はすべて成功している。

## User Setup Required

None - ホスト側の追加設定は不要。`$(id -u)` / `$(id -g)` は bash 組み込みで自動取得されるため、ユーザーが環境変数を設定する必要はない。

ただし **既存コンテナは close → 再 open が必須** (D-20):

- このプラン単体では破壊的変更ではないが、Phase 5 全体 (Plan 01 Dockerfile 再ビルド + Plan 02 entrypoint.sh 改修) とセットでリリースされるため、リリース時に既存 spirit-room-* コンテナは `spirit-room close` → `spirit-room open` で再作成する必要がある。
- HANDOVER.md へ追記推奨 (Phase 5 リリースノート):

```markdown
## Phase 5 リリース注意 (goku ユーザー化)

- 既存の `spirit-room-*` / `spirit-room-*-kaio` コンテナは **必ず `spirit-room close` で一度落としてから** `spirit-room open` / `spirit-room kaio` で開き直してください
- 新しい CLI + イメージ + entrypoint の組合せでのみ goku ユーザーが作成されます
- 既存の認証ボリューム (`spirit-room-auth` / `spirit-room-opencode-auth`) は破棄不要 — entrypoint が起動のたびに `chown $HOST_UID:$HOST_GID` で所有者を更新します
- `spirit-room enter` の SSH ユーザーが `goku@localhost` に変わります (パスワードは `spiritroom` のまま)
- `root@localhost` での SSH は Dockerfile 側で拒否されます (Plan 01)
```

## Next Phase Readiness

### Wave 2 (05-03) の成果物

- `spirit-room/spirit-room` の 4 箇所の差分が merge 後、Plan 01 (Dockerfile goku SSH 許可 + sudo + gosu) と Plan 02 (entrypoint goku 作成 + chown + su - goku tmux) と組合わさって Phase 5 の goal (goku 切替 + ホスト UID/GID 一致) が達成される前提。
- この plan は wave 2 で Plan 01 のみに依存 (`depends_on: [05-01]`) — Plan 02 と並列実行可能な設計だった。

### 残タスク (Phase 5 全体 merge 後のホスト側 live 検証)

**parallel worktree mode のため live Docker 検証は未実施。Phase 5 全 Plan merge + イメージ再ビルド後に、ホストで下記手順で E2E 検証する (Plan 05-03 の Task 3.4 how-to-verify を再掲):**

```bash
# 0. 前提: Phase 5 全 Plan merge 済み、build-base.sh 実行済み
cd spirit-room && ./build-base.sh && cd -

# 1. 既存 spirit-room-* コンテナを全部 close
spirit-room list
# 表示された各フォルダに対して:
spirit-room close <folder>

# 2. 検証用フォルダ + open
mkdir -p /tmp/spirit-room-phase5-open
spirit-room open /tmp/spirit-room-phase5-open
docker logs $(spirit-room list | awk '/phase5-open/{print $1}') 2>&1 | grep -E "goku|HOST_UID|chown"
# 期待: [INFO] goku ユーザーを作成 (UID=... GID=...) が見える

# 3. enter で goku 入室確認
spirit-room enter /tmp/spirit-room-phase5-open
# tmux 内で:
whoami        # => goku
id            # => uid=$(id -u on host) gid=$(id -g on host)
sudo whoami   # => root (NOPASSWD)
touch /workspace/phase5-cli-test.txt
ls -la /workspace/phase5-cli-test.txt  # => goku 所有
# Ctrl+B → D でデタッチ

# 4. ホスト側所有権確認
ls -la /tmp/spirit-room-phase5-open/phase5-cli-test.txt
# => ホストユーザー所有 (sudo 不要で rm できる)
rm /tmp/spirit-room-phase5-open/phase5-cli-test.txt

# 5. root SSH 拒否確認
ROOM_PORT=$(docker ps --filter "name=spirit-room-phase5-open" --format '{{.Ports}}' | grep -oE '[0-9]+->22' | cut -d- -f1)
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$ROOM_PORT" root@localhost whoami
# => Permission denied

# 6. kaio モード確認
mkdir -p /tmp/spirit-room-phase5-kaio
spirit-room kaio /tmp/spirit-room-phase5-kaio
# 自動入室。コンテナ内で:
whoami                                             # => goku
sudo whoami                                        # => root
ls -la /workspace/.claude-home/.credentials.json
# => lrwxrwxrwx ... goku goku ... -> /root/.claude-shared/.credentials.json
exit

# 7. 非回帰: list / close / logs
spirit-room list                              # 2 部屋
spirit-room logs /tmp/spirit-room-phase5-open
# Ctrl+C
spirit-room close /tmp/spirit-room-phase5-open
spirit-room close /tmp/spirit-room-phase5-kaio

# 8. クリーンアップ
rm -rf /tmp/spirit-room-phase5-open /tmp/spirit-room-phase5-kaio
```

### 準備完了事項

- CLI の 4 箇所差分がそのまま main にマージ可能
- Plan 01 / Plan 02 との依存関係: 05-03 は 05-01 の Dockerfile 修正 (PermitRootLogin=no, sudo, gosu) に依存。05-02 (entrypoint) との調整は wave 2 完了時に orchestrator 側で統合検証される想定。

### 潜在的懸念

- **entrypoint (Plan 02) が HOST_UID/HOST_GID 未設定時の fallback (`${HOST_UID:-1000}`) を持っているか未確認**: 本 Plan の CLI は常に `$(id -u)` / `$(id -g)` を渡すため通常は問題にならないが、CI 環境や手動 `docker run` では env 未渡しがあり得る。Plan 02 の entrypoint 側で `${HOST_UID:-1000}` を実装していれば OK。
- **cmd_auth の docker run --rm は変更していない**: 初回認証時は entrypoint はまだ走っていないため、認証ボリューム内の credentials.json が root 所有で作成される可能性がある。次に `spirit-room open` したとき entrypoint が chown するので最終的には goku 所有になる設計 (D-11)。

---

## Self-Check: PASSED

- `spirit-room/spirit-room` modified: FOUND
- Commit e6a4128 (Task 3.1): FOUND
- Commit cf97b0d (Task 3.2): FOUND
- Commit 241d4da (Task 3.3): FOUND
- `bash -n spirit-room/spirit-room`: exit 0
- HOST_UID=3, HOST_GID=3, chown literal present, goku@localhost 2 件 (ssh + help), root@localhost 0 件
- cmd_auth 内 chown 追加なし (D-11 遵守)

---

*Phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui*
*Plan: 03*
*Completed: 2026-04-17*
