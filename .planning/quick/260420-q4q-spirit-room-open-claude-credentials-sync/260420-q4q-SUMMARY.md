---
quick_id: 260420-q4q
status: complete
commit: d8ef6c9
---

# Quick 260420-q4q: spirit-room open で host の Claude credentials を毎回同期

## Changes

**File:** `spirit-room/spirit-room` (single file, 1 changed, +30 / -18)

| 箇所 | 変更内容 | 行数 |
|------|---------|------|
| 新ヘルパー追加 | `_sync_host_credentials()` を `_kochou_extra_args` の直後・`# ── コマンド: open` セクション区切りの直前に挿入 | L79-102 (新規 24 行) |
| `cmd_open` に呼び出し追加 | `docker volume create` 2 行の直後に `_sync_host_credentials` 呼び出しを挿入 (Q4Q-01) | L145-146 |
| `cmd_kaio` の重複同期ブロックを置換 | 旧 L192-209 の inline 同期ブロック (18 行) を `_sync_host_credentials` 呼び出し 1 行に差し替え (Q4Q-02) | L220-221 |

**未変更 (明示):** `cmd_auth` (L327-360 相当) は 1 文字も変更なし (Q4Q-03) — `git diff` hunk にも含まれていない。

## Function signature added

```bash
_sync_host_credentials()
```

- **引数:** なし (スクリプトスコープ変数 `$AUTH_VOLUME` / `$BASE_IMAGE` / `$HOME` を参照)
- **戻り値:** 常に 0 (host creds 無しケースで `return 0`、docker run 失敗時も `|| echo [WARN]` でフォールスルー)
- **挙動:**
  - `${HOME}/.claude/.credentials.json` が無ければ `[WARN] ホストに認証情報なし: ...` / `spirit-room auth を先に...` を出して return 0
  - 有れば `[INFO] ホストの最新認証情報をボリュームに同期中...` を出して `docker run --rm` で BASE_IMAGE の bash entrypoint から `cp → chown $HOST_UID:$HOST_GID → chmod 600` を実行
  - 失敗時は `[WARN] 認証情報同期に失敗` で続行 (set -e 下でも止めない)

## Verification results

| Check | Command | Expected | Actual |
|-------|---------|----------|--------|
| 1. 構文 | `bash -n spirit-room/spirit-room` | exit 0 | exit 0 (`SYNTAX_OK`) |
| 2. 呼び出し回数 | `grep -c _sync_host_credentials spirit-room/spirit-room` | 3 | 3 (L84 定義 + L146 cmd_open + L221 cmd_kaio) |
| 3. 重複ログ除去 | `grep -c 'ホストの最新認証情報をボリュームに同期中' spirit-room/spirit-room` | 1 | 1 (L92 ヘルパー内のみ) |

全 3 つの自動検証 PASS。

## 次のステップ (smoke test)

live smoke tests (creds 有り / creds 無し / kaio regression の 3 シナリオ) は orchestrator 側のステップで実施予定。本 executor 段階では静的検証 (`bash -n` + grep 出現回数 + diff 範囲確認) までに留めた。

## Self-Check: PASSED

- `spirit-room/spirit-room` 存在確認: OK (edit 済)
- commit `d8ef6c9` 存在確認: OK (`git log --oneline -1` で verify)
- 削除ファイルなし (`git diff --diff-filter=D HEAD~1 HEAD` で empty)
- `cmd_auth` 未変更: OK (diff hunk に含まれない)
