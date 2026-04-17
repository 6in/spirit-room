---
phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui
fixed_at: 2026-04-17T00:00:00Z
review_path: .planning/phases/05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui/05-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 5
skipped: 1
status: partial
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-04-17
**Source review:** `.planning/phases/05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui/05-REVIEW.md`
**Iteration:** 1
**Branch:** `phase/05-review-fix-iter1`

## Summary

| Metric | Count |
|---|---|
| Findings in scope (HIGH + MEDIUM) | 6 |
| Fixed | 5 |
| Skipped | 1 |

| Finding | Severity | Status | Commit |
|---|---|---|---|
| HIGH-01 | High | fixed | `f3a4607` |
| HIGH-02 | High | fixed | `ec6f27b` |
| MEDIUM-01 | Medium | fixed | `837faf1` |
| MEDIUM-02 | Medium | fixed | `6b9741e` |
| MEDIUM-03 | Medium | fixed | `28e53b9` |
| MEDIUM-04 | Medium | skipped (out of phase scope) | — |

Low/Info findings (LOW-01, LOW-02, LOW-03, IN-01, IN-02, IN-03) はスコープ外のためこの iteration では未対応。

---

## Fixed Issues

### HIGH-01: Ubuntu 24.04 既存 `ubuntu` ユーザー (uid=1000) との UID/GID 衝突

**Files modified:** `spirit-room/base/Dockerfile`
**Commit:** `f3a4607`
**Applied fix:** SSH 設定レイヤーの `RUN` に `userdel -r ubuntu 2>/dev/null || true` と `groupdel ubuntu 2>/dev/null || true` を追加。Ubuntu 24.04 ベースイメージにデフォルトで含まれる `ubuntu:x:1000:1000` を事前削除し、HOST_UID=1000 のホストで goku 作成時に UID 衝突が起きて `getpwuid(1000)` が `ubuntu` を返す name-resolution 問題を根絶。

### HIGH-02: HOST_UID 変更時に goku の UID が追従しない (ホスト移行時に所有権崩壊)

**Files modified:** `spirit-room/base/entrypoint.sh`
**Commit:** `ec6f27b`
**Applied fix:** `id goku &>/dev/null` で存在チェックが true だった場合でも、`id -u goku` / `id -g goku` を取得して `HOST_UID/HOST_GID` と比較。不一致なら `groupmod -g` + `usermod -u -o -g` で再割り当てし、続く `chown -R` が正しい所有者を再同期できるようにする。運用上は D-20 の「close → re-open」推奨を維持しつつ、`docker start`/`docker restart` を手動実行したケースの安全策として自動修復を実装。トップレベル実行のため `local` は使わず通常変数で受けている。

### MEDIUM-01: `ROOM_NAME` → `_TRAINING_CMD` → heredoc 経由のコマンドインジェクション

**Files modified:** `spirit-room/base/entrypoint.sh`
**Commit:** `837faf1`
**Applied fix:** 二重防御で injection 経路を遮断。

1. **入口サニタイズ:** entrypoint 冒頭で `ROOM_NAME="${ROOM_NAME//[^a-zA-Z0-9_-]/_}"` を実行し、`/`, `$`, `` ` ``, `'`, `;`, スペース等のシェルメタ文字を `_` に正規化。
2. **埋め込み値のエスケープ:** `_default_msg` を `printf -v _default_msg_q '%q' "$_default_msg"` で bash 安全な 1-word 表記にエスケープ。
3. **tmux send-keys の double-quote 包装を外す:** `_TRAINING_CMD` は既にエスケープ済みの形 (`echo \[...\]\ ...`) なので、heredoc 内の `tmux send-keys ... ${_TRAINING_CMD} C-m` をそのまま渡す。

`ROOM_NAME="test';touch /tmp/pwned;#"` の exploit 文字列がサニタイズ後 `test__touch__tmp_pwned__` になり、`/tmp/pwned` が作成されないことをローカルでテスト確認済み。

### MEDIUM-02: `~/.profile` 冪等チェックが値不一致を検出しない

**Files modified:** `spirit-room/base/entrypoint.sh`
**Commit:** `6b9741e`
**Applied fix:** 固定 prefix `export CLAUDE_CONFIG_DIR=` での grep 判定を止め、`sed -i '/^export CLAUDE_CONFIG_DIR=/d' ~/.profile` で既存行を一度削除してから最新値を append する方式に変更。異なる CLAUDE_CONFIG_DIR が渡されても確実に追従し、毎起動で delete → append するため最後の値が 1 行だけ残り冪等性も担保。

### MEDIUM-03: `claude auth status` が root で走り goku context を反映しない

**Files modified:** `spirit-room/base/entrypoint.sh`
**Commit:** `28e53b9`
**Applied fix:** `claude auth status` を `su - goku -c "... claude auth status"` に包んで goku コンテキストに揃えた。kaio モードでは `CLAUDE_CONFIG_DIR` を su 経由でも見えるよう `_auth_env="CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR} "` を `su -c` の先頭に付与。認証済み時のログメッセージも `[INFO] Claude Code 認証済み (goku context)` と明示化。

---

## Skipped Issues

### MEDIUM-04: `chown -R /workspace` の起動時パフォーマンス最適化

**File:** `spirit-room/base/entrypoint.sh:47`
**Reason:** Phase 5 のスコープはユーザー化の機能面修正に絞られており、パフォーマンス最適化は `v1` の範疇外 (フィクサー向けガイダンスにも「too large for this phase — document as skipped」と明記)。POC 用途の /workspace サイズでは体感レイテンシに影響しないため、現状のまま毎起動で `chown -R` する動作で機能上問題なし。
**Original issue:** 巨大ツリーをマウントした際に起動時の chown -R が数秒〜数十秒ブロックする可能性。`stat -c %u:%g /workspace` 一致時に skip する最適化を検討可能。

**Deferred to:** 将来のパフォーマンスチューニングフェーズ (v2+) で対応検討。現状のトップレベル所有者だけ見る早期 return は実装コスト 5 分程度で再導入可能。

---

## Verification Notes

- 全ての fix について `bash -n` による syntax check を実施し、パースエラー無しを確認。
- MEDIUM-01 は exploit 文字列 `"test';touch /tmp/pwned;#"` をサニタイズ → printf %q → heredoc の流れで再現テストし、`/tmp/pwned` が作成されない (インジェクション不成立) ことを確認済み。
- Docker イメージ再ビルド (`./build-base.sh`) と実機検証 (HIGH-01 の `docker run --rm -e HOST_UID=1000 ...`) は orchestrator の verifier phase に委譲。
- HIGH-02 / MEDIUM-03 は logic を含むため、実機 (2 ホスト・異なる UID でのボリューム持ち回し、goku 認証 OAuth flow) での人手確認を推奨。

---

_Fixed: 2026-04-17_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
