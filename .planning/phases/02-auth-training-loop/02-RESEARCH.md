# Phase 2: Auth & Training Loop - Research

**Researched:** 2026-04-13
**Domain:** Claude Code CLI 認証フロー / Docker ボリューム共有 / 自律エージェント実行
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | コンテナ内で Claude Code 認証が完了できる（`spirit-room auth` 経由） | cmd_auth は -it コンテナで `claude auth login` を呼ぶ → URL 表示 → ユーザーがホストブラウザで開く形式で動作する |
| AUTH-02 | 認証ボリューム（`spirit-room-auth`）が複数の部屋をまたいで共有される | `claude auth login` は `/root/.claude/.credentials.json` に書く。ボリュームが同じなら全コンテナで再認証不要 |
| LOOP-01 | `start-training.sh` が PHASE1 を実行し、依存パッケージをインストールして `.prepared` フラグを作成する | スクリプト実装済み。ただし `--dangerously-skip-permissions` が欠落しており Bash ツールがハングする |
| LOOP-02 | `start-training.sh` が PHASE2 を実行し、MISSION.md の実装完了後に `.done` フラグを作成する | スクリプト実装済み。同上の問題 |
| LOOP-03 | コンテナ再起動後に `.prepared`/`.done` フラグを検出してフェーズをスキップし、正しいフェーズからレジュームする | 冪等ロジック正しく実装済み（while ループ先頭でフラグチェック） |
| LOOP-04 | `claude -p` のフラグ構文が現行バージョンで正常動作する | `--allowedTools` は v2.1.104 で有効。ただし `--dangerously-skip-permissions` が必要。`LS` は無効ツール名（無視される）。修正が必要 |
</phase_requirements>

---

## Summary

Phase 2 が対象とするのは「認証共有」と「修行ループの自律実行」の 2 つの技術領域。

**認証フロー（AUTH-01 / AUTH-02）:** `claude auth login` は OAuth PKCE フローでブラウザ URL を端末に表示する方式を採用している。Docker コンテナ内であっても `-it` フラグ付きの対話型コンテナで起動すれば URL が表示され、ユーザーがホスト側ブラウザで完了できる。認証結果は `/root/.claude/.credentials.json` に保存され、Docker 名前付きボリューム `spirit-room-auth` を `/root/.claude` にマウントすることで複数コンテナ間で共有できる。この設計は既に `spirit-room auth` コマンドで正しく実装されている。

**修行ループ（LOOP-01〜04）:** `start-training.sh` の冪等ロジック（フラグファイル先頭チェック）は正しく実装されている。ただし `run_claude` 関数に重大な問題がある。`claude -p` で Bash ツールを実行しようとすると、`--dangerously-skip-permissions` フラグがないためにパーミッション確認プロンプトが出てスクリプトがハングする。この 1 行の修正で LOOP-01〜04 のすべての問題が解決する。

**Primary recommendation:** `run_claude` 関数に `--dangerously-skip-permissions` を追加し、ツール名 `LS` を除去すること。それ以外の設計は正しく動作する。

---

## Standard Stack

### Core

| ライブラリ/ツール | バージョン | 用途 | 根拠 |
|------------------|-----------|------|------|
| `@anthropic-ai/claude-code` | 2.1.104 (latest) | 自律エージェント実行エンジン | プロジェクト既定 |
| Docker named volume | 29.4.0 (host) | 認証情報の永続化・共有 | 既存設計 |
| bash | 5.1.16 | スクリプト制御・フラグファイル管理 | 既存設計 |

### Supporting

| ツール | 用途 | 備考 |
|--------|------|------|
| `claude --dangerously-skip-permissions` | コンテナ内での Bash ツール無人実行 | サンドボックスに推奨。**現在欠落** |
| `claude auth status --json` | 認証状態の機械的チェック | `--json` デフォルトのため `--text` を明示する必要がある |

**インストール不要:** 全ツールは Phase 1 完了時点でイメージに焼き込み済み。

**バージョン確認（2026-04-13 実測）:**
```
npm view @anthropic-ai/claude-code version → 2.1.104
docker --version → Docker version 29.4.0
```
[VERIFIED: npm registry, docker CLI]

---

## Architecture Patterns

### Claude CLI 非対話実行パターン

**What:** `-p` (--print) モードで Claude Code を非対話的に実行し、出力を `tee -a $LOG_FILE` でログに記録する。
**When:** シェルスクリプトから Claude に処理を委任するすべての場面。

```bash
# Source: claude --help (v2.1.104, verified 2026-04-13)
# CORRECT pattern for autonomous execution in container
claude \
  --dangerously-skip-permissions \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  -p "$prompt" \
  2>&1 | tee -a "$LOG_FILE"
```

[VERIFIED: claude --help, テスト実行確認]

**注意:** `--dangerously-skip-permissions` なしで `--allowedTools "Bash,..."` を使うと、Bash コマンド実行ごとに確認プロンプトが出て無人実行がハングする。コンテナはサンドボックスなのでこのフラグは安全。

### フラグファイル冪等パターン（既存・正しい実装）

```bash
# Source: spirit-room/base/scripts/start-training.sh (現行実装)
while true; do
    [ -f "$PREPARED_FLAG" ] && { log "PREPARE済み、スキップ"; break; }
    # ... 処理 ...
    [ -f "$PREPARED_FLAG" ] && { log "PREPARE完了"; break; }
    sleep 3
done
```

このパターンは LOOP-03 を正しく満たしている。変更不要。

### Docker ボリュームによる認証共有パターン

```bash
# Source: spirit-room/spirit-room cmd_auth (現行実装)
docker run -it --rm \
    -v "spirit-room-auth:/root/.claude" \
    "$BASE_IMAGE" \
    bash -c "claude auth login"
```

`claude auth login` が `/root/.claude/.credentials.json` に OAuth トークンを書き込む。ボリューム `spirit-room-auth` はすべての部屋コンテナに同じパスでマウントされているため再認証不要。[VERIFIED: .credentials.json キー確認、docker volume inspect]

### Anti-Patterns to Avoid

- **`LS` をツール名として指定する:** `LS` は Claude Code の有効ツール名ではない。`claude --help --tools default` に表示されるリスト（`Bash,Read,Write,Edit,Glob,Grep,Agent,...`）を使う。現行スクリプトでは無視されるだけだが、意図を誤解させる。
- **`--dangerously-skip-permissions` なしで Bash ツールを使う:** `-p` モードでも Bash 実行時にパーミッション確認が出る。コンテナ内ではこのフラグを必ず付ける。
- **`service ssh start` を auth コンテナで実行する:** `cmd_auth` の `bash -c "service ssh start > /dev/null; claude auth login"` は SSH 起動が不要（auth はネットワーク URL 方式）。ただし害はなく、削除は任意。

---

## Don't Hand-Roll

| 問題 | 作らないこと | 使うもの | 理由 |
|------|-------------|----------|------|
| OAuth 認証フロー | 独自のブラウザ起動 / token 管理 | `claude auth login` | Claude Code CLI が PKCE フローを完全管理。トークンリフレッシュも自動 |
| ツールパーミッション管理 | 独自の確認ダイアログ回避 | `--dangerously-skip-permissions` | CLI 既定のフラグ。サンドボックス用途に設計されている |
| エージェント再実行ループ | 複雑なリトライ管理 | `while true; sleep 3; done` | シンプルなフラグファイルチェックで十分。追加ライブラリ不要 |

---

## Common Pitfalls

### Pitfall 1: `--dangerously-skip-permissions` 欠落でループがハング

**What goes wrong:** `start-training.sh` が `run_claude` を呼び、Claude が Bash ツールで `npm install` 等を実行しようとする。`--dangerously-skip-permissions` がないと「このコマンドを実行してよいですか？」的な対話プロンプトが出て stdin を待機。`-p` モードなので stdin には何も来ずタイムアウト or 無限待機。

**Why it happens:** `-p` モードはワークスペーストラスト確認をスキップするが、Bash ツールのパーミッション確認とは別の機構。

**How to avoid:** `run_claude` 関数に `--dangerously-skip-permissions` を追加する（1 行の変更）。

**Warning signs:** `start-training.sh` を実行してもログが止まり、プロセスが残り続ける。

[VERIFIED: テスト実行確認 — `--dangerously-skip-permissions` なしで `timeout 10 claude --allowedTools "Bash" -p "..."` → Terminated]

### Pitfall 2: 認証ボリュームが空の状態でコンテナ起動

**What goes wrong:** `spirit-room auth` を実行する前に `spirit-room open` を実行すると、認証なしでコンテナが起動する。`start-training` を呼ぶと Claude が API 呼び出しで認証エラーを返す。

**Why it happens:** `spirit-room open` はボリュームが存在しない場合に作成するだけで、認証ファイルが入っているかチェックしない。

**How to avoid:** ユーザードキュメント・entrypoint.sh の警告メッセージに「先に `spirit-room auth` を実行すること」を明記。`entrypoint.sh` は既に未認証チェックを行い `claude auth login` の実行を促している。

**Warning signs:** `entrypoint.sh` が「未認証」バナーを表示する。

### Pitfall 3: `claude auth status` の終了コード依存

**What goes wrong:** `entrypoint.sh` の `if ! claude auth status &>/dev/null 2>&1; then` が想定外の終了コードを返す。

**Why it happens:** `claude auth status` は認証済みで exit 0、未認証時の exit code は CLI バージョンで変わる可能性がある。

**How to avoid:** 現行の実装で問題ない（実際に動作確認済み）。変更不要。

[VERIFIED: ホスト上で `claude auth status` → exit 0、JSON 出力で loggedIn: true を確認]

---

## Code Examples

### 修正後の `run_claude` 関数

```bash
# Source: 現行 start-training.sh の問題を修正したバージョン
run_claude() {
    local prompt="$1"
    case "$ENGINE" in
        claude)
            claude \
                --dangerously-skip-permissions \
                --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
                -p "$prompt" \
                2>&1 | tee -a "$LOG_FILE"
            ;;
        opencode)
            opencode -p "$prompt" 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
}
```

変更点:
1. `--dangerously-skip-permissions` を追加（LOOP-04 対応、**必須**）
2. `LS` を削除、`Glob,Grep` を追加（より正確なツールセット）

### `spirit-room auth` 動作確認コマンド（テスト用）

```bash
# 一時コンテナで認証フローが起動することを確認
docker run -it --rm \
    -v "spirit-room-auth:/root/.claude" \
    spirit-room-base:latest \
    bash -c "claude auth status --text || claude auth login"
```

### 認証ボリューム共有の検証

```bash
# ボリューム作成・認証情報の存在確認
docker volume inspect spirit-room-auth
docker run --rm \
    -v "spirit-room-auth:/root/.claude" \
    spirit-room-base:latest \
    bash -c "claude auth status --text"
```

---

## State of the Art

| 旧アプローチ | 現行アプローチ | 変更時期 | 影響 |
|-------------|--------------|---------|------|
| `claude code` サブコマンド | `claude` トップレベルコマンド | v1.x → v2.x | start-training.sh は既に正しい `claude` コマンドを使用 |
| `-p` フラグなし（対話モード） | `-p` / `--print` フラグ（非対話） | 長期安定 | 非対話スクリプト実行の標準 |

**現行 v2.1.104 で確認された有効フラグ:**
- `--allowedTools` / `--allowed-tools` — カンマまたはスペース区切り [VERIFIED]
- `--dangerously-skip-permissions` — パーミッションチェック完全バイパス [VERIFIED]
- `-p` / `--print` — 非対話出力モード [VERIFIED]

---

## Environment Availability

| 依存 | 用途 | 利用可能 | バージョン | フォールバック |
|------|------|---------|-----------|--------------|
| Docker | コンテナ管理 | ✓ | 29.4.0 | なし（必須） |
| `spirit-room-base:latest` | 修行コンテナのベースイメージ | ✓ | Phase 1 で build 済み | なし（Phase 1 に依存） |
| `spirit-room-auth` volume | 認証情報共有 | ✓ | 既存 | `docker volume create spirit-room-auth` |
| `claude` CLI | 修行エンジン | ✓（ホスト: 2.1.104、イメージ内も同等） | 2.1.104 | opencode（v2 スコープ） |

[VERIFIED: docker --version, claude --version, docker volume ls]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | イメージ内の Claude Code CLI バージョンが `--dangerously-skip-permissions` をサポートしている | Code Examples | イメージ内が古いバージョンの場合フラグが無効になる。`spirit-room-base:latest` の claude バージョンをビルド時に確認する必要がある |
| A2 | `claude auth login` の OAuth URL 表示フローは v2.1.x で変わっていない | Architecture Patterns | 将来バージョンで変更されるとドキュメント更新が必要 |

---

## Open Questions

1. **イメージ内の claude バージョン確認**
   - What we know: ホスト上は 2.1.104、`npm install -g @anthropic-ai/claude-code` でインストール済み
   - What's unclear: ビルド時のキャッシュでバージョンが古い可能性
   - Recommendation: Plan に「コンテナ内で `claude --version` を確認するタスク」を含める

2. **opencode エンジンの動作（v2 スコープだが影響がある）**
   - What we know: `opencode-ai` が Dockerfile に含まれている
   - What's unclear: `-p` フラグが opencode-ai で有効か未確認
   - Recommendation: Phase 2 スコープでは `claude` エンジンのみ検証。opencode は v2 スコープのまま

---

## Sources

### Primary (HIGH confidence)
- `claude --help` (v2.1.104) — フラグ構文、ツール名リスト、-p モード動作を直接確認
- `claude auth status --json` — 認証状態、`.credentials.json` のキー構造
- `npm view @anthropic-ai/claude-code dist-tags` — 最新バージョン確認
- テスト実行 — `--dangerously-skip-permissions` あり/なしでの動作差異を実測

### Secondary (MEDIUM confidence)
- `spirit-room/spirit-room`, `spirit-room/base/scripts/start-training.sh`, `spirit-room/base/entrypoint.sh` — 現行実装の精査

---

## Metadata

**Confidence breakdown:**
- AUTH フロー: HIGH — `claude auth login` を実際に実行して URL 表示フローを確認
- `--dangerously-skip-permissions` 必要性: HIGH — タイムアウトテストで実証
- フラグ冪等ロジック: HIGH — コード精査で正しい実装を確認
- ツール名正確性: HIGH — `claude --tools default --print` で全リスト取得

**Research date:** 2026-04-13
**Valid until:** 2026-07-13（Claude Code CLI は更新頻度が高いため 90 日）
