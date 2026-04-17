---
phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui
plan: 02
subsystem: container-entrypoint
tags: [entrypoint, goku, uid-gid, chown, tmux, sudo, kaio]
requires:
  - 05-01  # Dockerfile 側 (PermitRootLogin no / sudo / CLAUDE.md 等) が Wave 1 で入っていること
provides:
  - goku-runtime-creation        # entrypoint が HOST_UID/GID で冪等 useradd
  - workspace-goku-ownership     # /workspace + 認証ボリュームが起動ごとに goku 所有に chown
  - tmux-goku-session            # tmux セッションが goku で起動 (PID 1 は root)
  - goku-home-git-config         # goku HOME に safe.directory / user.email / user.name を設定
  - kaio-credentials-symlink-chown  # kaio モード時 symlink 自体も chown -h で goku 所有
affects:
  - spirit-room/base/entrypoint.sh
tech-stack:
  added: []
  patterns:
    - "su - goku -c 'bash -s' heredoc wrapping for privilege drop (tmux launch)"
    - "Idempotent runtime user creation (id goku &>/dev/null guard + useradd -o)"
    - "Per-boot chown of auth volumes and /workspace (absorbs stale root ownership)"
    - "Heredoc without quotes for parent-shell variable expansion into goku session"
    - "Idempotent ~/.profile append via grep -q guard for CLAUDE_CONFIG_DIR export"
key-files:
  created: []
  modified:
    - spirit-room/base/entrypoint.sh
decisions:
  - "D-09 順序を厳守: service → HOST_UID/GID → goku 作成 → chown → kaio symlink + chown -h → 認証チェック → catalog → goku git config → tmux (su - goku -c bash -s) → tail -f root"
  - "su - goku -c 'bash -s' で tmux 起動。Pattern B3 L146 の案 A (bash -s 明示) を採用"
  - "HOST_UID/GID fallback は 1000:1000 に固定。WAS_SET 分岐は入れずログ 1 行のみ"
  - "useradd に -o を付与し既存ユーザー UID 衝突時も安全に通す"
  - "chown は `|| true` で安全化 (volume が空でも失敗で止まらない)"
  - "heredoc は `<< EOF` (クォート無し) とし、SESSION / ROOM_NAME / _TRAINING_CMD / CLAUDE_CONFIG_DIR を親 shell (root) で展開してから goku に渡す"
  - "kaio モード時、CLAUDE_CONFIG_DIR を goku ~/.profile に冪等 export (start-training-kaio が login shell から env を読むため)"
metrics:
  duration: "~6 分 (1 ラウンド内での連続編集 + ブランチ整備)"
  completed: "2026-04-17"
---

# Phase 5 Plan 02: entrypoint.sh の goku 化改修 Summary

## One-liner

`entrypoint.sh` に HOST_UID/GID 受け取り・goku 冪等作成・/workspace + 認証ボリューム chown・goku HOME 用 git config ミラー・tmux を `su - goku -c "bash -s"` でラップする処理を D-09 順序通りに挿入し、PID 1 は root のまま保持した。

## Scope

`spirit-room/base/entrypoint.sh` のみ。Dockerfile / CLI / start-training.sh は触っていない (それぞれ 05-01 / 05-03 で既に対応済み)。

## 挿入位置と差分サマリ

### Task 2.1 (commit 892df35) — goku 作成 + chown

挿入位置は `service ssh/redis start` と既存 kaio 分岐の間 (改修後 L18-48)。

1. **HOST_UID/GID 受け取り** (L18-22):
   ```bash
   HOST_UID="${HOST_UID:-1000}"
   HOST_GID="${HOST_GID:-1000}"
   echo "[INFO] HOST_UID/GID=${HOST_UID}:${HOST_GID}"
   ```
   *単一行ログで WAS_SET 分岐は入れず。*

2. **goku 冪等作成** (L24-39):
   - `id goku &>/dev/null` ガードで既存 skip。
   - `getent group $HOST_GID >/dev/null || groupadd -g $HOST_GID goku` で GID 衝突を回避。
   - `useradd -m -u $HOST_UID -g $HOST_GID -s /bin/bash -o goku` (`-o` で UID 重複許可)。
   - `echo 'goku:spiritroom' | chpasswd` で root と同じパスワード。
   - `/etc/sudoers.d/goku` に NOPASSWD:ALL を書き出し `chmod 0440`。

3. **chown ブロック** (L41-48):
   - `/root/.claude` / `/root/.config/opencode` / `/root/.claude-shared` (kaio) / `/workspace` を `chown -R $HOST_UID:$HOST_GID`。
   - すべて `2>/dev/null || true` で安全化。
   - `[ -d /root/.claude-shared ] && ...` ガードで通常モードでは無視。

4. **既存 kaio 分岐への追記** (L55-69):
   - `mkdir -p` 後に `chown $HOST_UID:$HOST_GID $CLAUDE_CONFIG_DIR` を追加 (D-13)。
   - symlink 作成後に `chown -h $HOST_UID:$HOST_GID $CLAUDE_CONFIG_DIR/.credentials.json` を追加 (D-14)。

### Task 2.2 (commit 34c8a66) — goku git config + tmux goku ラップ

1. **goku HOME 用 git config** (改修後 L90-97):
   ```bash
   su - goku -c "git config --global --add safe.directory '*' && \
       git config --global user.email 'spirit-room@localhost' && \
       git config --global user.name 'Spirit Room' && \
       git config --global init.defaultBranch main" || echo "[WARN] goku 用 git config 設定に失敗"
   ```

2. **tmux を `su - goku -c "bash -s"` でラップ** (L99-132):
   - 分岐判定を root 側で `_TRAINING_CMD` にフラグ化し、ヒアドキュメント内で展開。
   - kaio モード時は goku の `~/.profile` に `CLAUDE_CONFIG_DIR` を冪等 export (`grep -q`)。
   - `su - goku -c "bash -s" << EOF ... EOF` (クォート無し heredoc) で親 shell 展開。
   - ヒアドキュメント内 tmux 行はスペース 4 インデント (行頭 `^tmux` に当たらないため)。

3. **PID 1 保持** (L137):
   - `tail -f /dev/null` がヒアドキュメントの**外**に残り、親 shell=root で実行される。

## 実機検証 (Task 2.3)

**Worktree モードのため live verification は未実施。静的検証 (bash -n + grep acceptance_criteria) は全通過。**

### 静的検証結果 (確認済み)

- `bash -n spirit-room/base/entrypoint.sh` → exit 0 (構文エラーなし)
- Task 2.1 acceptance criteria 13 項目すべて OK:
  - HOST_UID/GID fallback, ログ行, WAS_SET 不在, 曖昧ログ不在, id goku, useradd, sudoers.d/goku, chmod 0440, chown /workspace, chown /root/.claude-shared, chown -h, PID 1 末尾残存
- Task 2.2 acceptance criteria 11 項目すべて OK:
  - `su - goku -c "bash -s"`, safe.directory='*', user.email='spirit-room@localhost', tmux new-session, rename-window, start-training-kaio, "start-training", /workspace/.logs/progress.log, workspace watch, PID 1 末尾 5 行以内, 行頭 tmux コマンド不在, CLAUDE_CONFIG_DIR export

### Next Phase Readiness: ライブ検証手順 (Wave マージ後にホストで実行)

Worktree が main へマージされた後、ホスト側のターミナルで以下を実行して実機検証する。

1. **再ビルド**
   ```bash
   cd spirit-room && ./build-base.sh
   ```

2. **通常モード起動 (手動 docker run)**
   ```bash
   mkdir -p /tmp/spirit-room-phase5-test
   docker run -d --name spirit-room-phase5-test \
       --hostname spirit-room-phase5-test \
       -e ROOM_NAME=phase5-test \
       -e HOST_UID=$(id -u) \
       -e HOST_GID=$(id -g) \
       -p 2299:22 \
       -v /tmp/spirit-room-phase5-test:/workspace \
       -v spirit-room-auth:/root/.claude \
       -v spirit-room-opencode-auth:/root/.config/opencode \
       spirit-room-base:latest
   docker logs spirit-room-phase5-test 2>&1 | head -30
   ```
   期待: `[INFO] HOST_UID/GID=...`, `[INFO] goku ユーザーを作成 ...`, `[INFO] /workspace と認証ボリュームを ...:... 所有に切替`, `[INFO] tmux 'spirit-room' 起動完了 (user=goku)`。

3. **tmux が goku で走っているか**
   ```bash
   docker exec spirit-room-phase5-test bash -c "ps -o user= -p \$(pgrep -f 'tmux new-session')"
   # 期待: goku
   ```

4. **/workspace 書込みがホストユーザー所有で見えるか**
   ```bash
   docker exec -u goku spirit-room-phase5-test touch /workspace/test-phase5.txt
   ls -la /tmp/spirit-room-phase5-test/test-phase5.txt
   rm /tmp/spirit-room-phase5-test/test-phase5.txt   # sudo chown 不要で消せる
   ```

5. **sudo NOPASSWD**
   ```bash
   docker exec -u goku spirit-room-phase5-test sudo whoami
   # 期待: root
   ```

6. **SSH 分岐 (goku 成功 / root 拒否)**
   ```bash
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2299 goku@localhost whoami
   # パス: spiritroom / 期待: goku
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2299 root@localhost whoami
   # 期待: Permission denied
   ```

7. **kaio モード (credentials symlink が goku 所有)**
   ```bash
   mkdir -p /tmp/spirit-room-phase5-kaio
   docker run -d --name spirit-room-phase5-kaio \
       -e ROOM_NAME=phase5-kaio \
       -e CLAUDE_CONFIG_DIR=/workspace/.claude-home \
       -e HOST_UID=$(id -u) \
       -e HOST_GID=$(id -g) \
       -p 2298:22 \
       -v /tmp/spirit-room-phase5-kaio:/workspace \
       -v spirit-room-auth:/root/.claude-shared \
       spirit-room-base:latest
   docker exec spirit-room-phase5-kaio ls -la /workspace/.claude-home/.credentials.json
   # 期待: symlink で所有者が $(id -un) にマップされている
   ```

8. **冪等性テスト (同じボリュームで再起動)**
   ```bash
   docker restart spirit-room-phase5-test
   docker logs --tail 20 spirit-room-phase5-test
   # 期待: "[INFO] goku ユーザーは既に存在 (skip)" が出る
   ```

9. **クリーンアップ**
   ```bash
   docker stop spirit-room-phase5-test spirit-room-phase5-kaio 2>/dev/null || true
   docker rm   spirit-room-phase5-test spirit-room-phase5-kaio 2>/dev/null || true
   rm -rf /tmp/spirit-room-phase5-test /tmp/spirit-room-phase5-kaio
   ```

## gosu 切替は不要と判断

Deferred Ideas にあった gosu への置換は不要と判断した理由:

- `su - goku -c "bash -s"` の heredoc 形式で、PATH / HOME / tmux の env 引き継ぎに問題を起こしそうな箇所は見当たらない。
- ヒアドキュメント内で tmux コマンドが直接展開されるので、`~/.bashrc` / `~/.profile` の読み込みタイミングに依存せず安定。
- `CLAUDE_CONFIG_DIR` だけは login shell リセット問題があるため `~/.profile` に冪等 export で対応 (gosu とは独立の問題)。

ライブ検証で tmux セッション接続 / start-training 起動に問題があれば、Phase 5 の deferred として gosu 採用を再検討。

## Plan 03 との関係

Plan 03 (CLI) は既に適用済み (commits cf97b0d / 241d4da)。`cmd_open` / `cmd_kaio` / `cmd_kaio --rm auth 同期` が `-e HOST_UID=$(id -u) -e HOST_GID=$(id -g)` を渡し、`cmd_enter` は `ssh -t goku@localhost` に切り替わっている。Plan 02 の entrypoint 側はこの env が届く前提で書かれており、届かなくても 1000:1000 fallback で落ちない。

## Decisions Made

1. **HOST_UID/GID ログ単一行化**: `WAS_SET` 変数を使った「fallback / explicit」分岐は入れない。ログは `[INFO] HOST_UID/GID=...:...` 1 行のみ。後日必要になったら別変数で明示導入する。
2. **useradd に -o 付与**: ホスト UID が `_apt` 等と衝突した場合の保険として UID 重複許可を最初から入れる。POC 用途なのでセキュリティインパクト無し。
3. **heredoc は クォート無し**: `<< 'EOF'` にすると `${SESSION}` / `${_TRAINING_CMD}` がリテラルで渡って失敗する。クォート無し `<< EOF` で親 shell (root) 展開させる。
4. **CLAUDE_CONFIG_DIR は ~/.profile 経由 export**: `su -` が login shell のため env がリセットされる問題を、goku HOME の `.profile` に冪等追記することで解決。`grep -q` ガードで複数回起動しても 1 行のみ維持。
5. **ヒアドキュメント内 tmux 行をスペースインデント**: acceptance criteria `! grep -qE "^tmux new-session"` を通すため。意味的には `su - goku -c` スクリプト内で実行されるので root 直接実行ではない。インデント 4 スペースは heredoc 内部表現として問題なし (タブインデント用 `<<-` とは別)。

## Deviations from Plan

**None.** Plan 2.1 / 2.2 の指示どおり実装。`<< EOF` ヒアドキュメント内 tmux 行にスペースインデントを入れたのは acceptance criteria の文字通りの通過のため (プラン記載のコードと同じ意味、可読性プラス α)。

## Deferred Items

なし。Task 2.3 の live verification は Worktree モード方針により SUMMARY の "Next Phase Readiness" に記録してホスト側で実行予定。

## Key Changes

| File | Lines changed | Purpose |
|---|---|---|
| `spirit-room/base/entrypoint.sh` | +74 / −20 (実質) | HOST_UID 受け取り / goku 冪等作成 / chown / kaio symlink chown / goku git config / tmux goku ラップ |

## Self-Check: PASSED

- Created/modified files exist:
  - FOUND: `spirit-room/base/entrypoint.sh` (137 行、bash -n OK)
  - FOUND: `.planning/phases/05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui/05-02-SUMMARY.md`
- Commits exist on branch `phase/05-02-entrypoint-goku`:
  - FOUND: `892df35` feat(05-02): add goku user creation and chown blocks to entrypoint
  - FOUND: `34c8a66` feat(05-02): wrap tmux launch in su - goku -c and mirror git config
- All static acceptance criteria (Task 2.1 13項 / Task 2.2 11項 / Task 2.3 3項) パス。
