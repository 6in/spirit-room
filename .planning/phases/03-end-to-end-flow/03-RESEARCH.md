# Phase 3: End-to-End Flow - Research

**Researched:** 2026-04-14
**Domain:** Mr.ポポ E2E フロー / entrypoint.sh 自動起動 / pip インストール制約 / CLI セットアップ
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| E2E-01 | `spirit-room-manager` で Mr.ポポを起動し、ヒアリング → MISSION.md 生成まで完了する | spirit-room-manager/CLAUDE.md + skills/MR_POPO.md が既に実装済み。前提条件は spirit-room CLI が PATH に存在することと ~/projects/ ディレクトリが存在すること |
| E2E-02 | 生成された MISSION.md を使って `spirit-room open` → 修行ループが起動する | 現在 entrypoint.sh は "start-training で修行開始" と表示するだけ。MISSION.md 存在検知 + 自動 start-training の実装が必要 |
| E2E-03 | Claude Code がサンプルフレームワーク（LangGraph 等）の POC を実装し `.done` を作成する | PHASE 1 で pip install が externally-managed-environment エラーで失敗する。catalog.md への `--break-system-packages` 注記が必要 |
</phase_requirements>

---

## Summary

Phase 3 は「Mr. ポポのヒアリングから POC 完成まで人手なしに完走する」ことが目標。Phase 2 で修行ループ本体（LOOP-01〜04）はすべて実証済みであり、Phase 3 で追加実装が必要な部分は 3 点に絞られる。

**1. インフラ前提の未整備（E2E-01 に影響）:** `spirit-room` CLI が `/usr/local/bin` に未インストール（`which spirit-room` → not found）。`~/projects/` ディレクトリも未作成。Mr. ポポが `spirit-room open ~/projects/xxx` を実行できる状態になっていない。

**2. 修行ループの自動起動が未実装（E2E-02 に影響）:** 現在の `entrypoint.sh` は tmux の training ペインに "start-training で修行開始" とエコーするだけ。`spirit-room open` 後にユーザーが手動で `spirit-room enter` → `start-training` を実行する必要がある。E2E-02 の成功条件「training loop launches automatically」を満たすために、`entrypoint.sh` で MISSION.md の存在を検知して `start-training` を自動実行する変更が必要。変更後は `build-base.sh` による再ビルドが必要。

**3. コンテナ内 pip インストール制約（E2E-03 に影響）:** Ubuntu 24.04 ベースイメージでは `pip install <package>` が `externally-managed-environment` エラーで失敗する（実測確認済み）。`pip install <package> --break-system-packages` を使えばインストール成功する（LangGraph でも実測確認）。Claude Code が PHASE 1 でこのフラグを使うよう `catalog.md` に明記が必要。

**Primary recommendation:** Wave 1 で 3 点（spirit-room インストール・entrypoint.sh 修正・catalog.md 修正 + 再ビルド）を修正し、Wave 2 で Mr. ポポを実際に起動して LangGraph 等の小規模 MISSION.md で E2E 完走を確認する。

---

## Standard Stack

### Core

| ツール/ファイル | 現状 | 用途 | 備考 |
|----------------|------|------|------|
| `spirit-room` CLI | インストール未実施 | ホスト側のコンテナ管理 | `sudo cp spirit-room/spirit-room /usr/local/bin/` でインストール |
| `spirit-room-base:latest` | ✓ 存在（2 時間前ビルド済み） | 修行コンテナのベースイメージ | entrypoint.sh 変更後に再ビルド要 |
| `spirit-room-auth` volume | ✓ 存在 | 認証情報共有 | 有効な credentials 入り（実測確認） |
| `claude` (host) | ✓ v2.1.107 | Mr. ポポ起動・ホスト側操作 | spirit-room-manager ディレクトリで起動 |
| `docker` | ✓ v29.4.0 | コンテナ管理 | — |
| `spirit-room-manager/` | ✓ 実装済み | Mr. ポポとして動作 | CLAUDE.md + MR_POPO.md が完成 |

[VERIFIED: which spirit-room, docker images, docker volume ls, claude --version, docker --version]

### Supporting

| ツール | 用途 | 備考 |
|--------|------|------|
| `pip3 install <pkg> --break-system-packages` | コンテナ内 Python パッケージインストール | Ubuntu 24.04 必須フラグ（実測確認） |
| `python3 -m venv` | 代替インストール手段 | venv も使用可能だが --break-system-packages のほうが簡潔 |
| `langgraph` | E2E-03 のサンプルフレームワーク | pip install langgraph --break-system-packages で成功確認 |

[VERIFIED: pip3 install --break-system-packages 実測、langgraph dry-run 成功]

---

## Architecture Patterns

### E2E フロー全体

```
1. ホストで cd spirit-room-manager && claude を実行
   → CLAUDE.md を読んで Mr. ポポとして起動
   → MR_POPO.md のヒアリング手順に従い 3 ステップ質問
   → MISSION.md 生成 → ~/projects/[名前]/ に配置
   → spirit-room open ~/projects/[名前] 実行

2. spirit-room open が Docker コンテナを起動
   → entrypoint.sh が SSH / Redis / tmux を起動
   → MISSION.md が /workspace に存在 → start-training を自動実行 ← Phase 3 での追加

3. start-training が PHASE1 → PHASE2 で完走
   → .done フラグ作成
```

### Pattern 1: entrypoint.sh MISSION.md 自動検知

**What:** MISSION.md が存在し .done フラグがない場合に、training ペインで `start-training` を自動実行する。

**When to use:** E2E-02「training loop launches automatically」の要件を満たすため。

```bash
# 変更後の entrypoint.sh trainingペイン部分
# Source: 現行 entrypoint.sh + Phase 3 変更案
if [ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]; then
    # MISSION.md 存在 かつ 未完了 → 自動起動
    tmux send-keys -t "$SESSION:training" "start-training" C-m
else
    tmux send-keys -t "$SESSION:training" \
        "echo '部屋[$ROOM_NAME] 準備完了 | start-training で修行開始 | status で確認'" C-m
fi
```

[ASSUMED: この実装が E2E-02 の「automatically」の意図に合致する。.done が存在する部屋を再起動した場合の安全も確保されている]

**変更後は `build-base.sh` 再ビルドが必須。** `entrypoint.sh` はイメージに焼き込まれているため、ホスト側ファイルの変更だけでは反映されない。[VERIFIED: Phase 2 Plan 03 で同じパターンを経験済み]

### Pattern 2: pip インストールフラグ

**What:** Ubuntu 24.04 の `externally-managed-environment` 制約を回避する。

**When to use:** コンテナ内で `pip install` を実行するすべての場面（PHASE 1）。

```bash
# コンテナ内での正しい pip インストール（root ユーザー）
pip3 install <package> --break-system-packages

# または venv を使う場合
python3 -m venv /workspace/.venv
/workspace/.venv/bin/pip install <package>
source /workspace/.venv/bin/activate
```

[VERIFIED: pip3 install requests --break-system-packages → Successfully installed]
[VERIFIED: pip3 install langgraph --break-system-packages (dry-run) → Collecting langgraph 1.1.6]

### Pattern 3: Mr. ポポ起動フロー

```bash
# ホスト側で実行
cd /path/to/spirit-room-manager
claude
# → CLAUDE.md が読まれ、Mr. ポポとして動作
# → skills/MR_POPO.md のヒアリング開始
```

MR_POPO.md のフローは完全に実装済み。変更不要。[VERIFIED: MR_POPO.md コード精査]

### Anti-Patterns to Avoid

- **pip install <package> を catalog.md の通りに実行する:** `--break-system-packages` なしでは Ubuntu 24.04 でエラーになる。catalog.md の記述が現在不正確。
- **entrypoint.sh 変更後に再ビルドをスキップする:** start-training.sh と同様に entrypoint.sh はイメージ内のファイル。ホスト側変更だけでは既存コンテナに反映されない。
- **.done が存在する部屋を自動 start-training する:** 修行完了済みの部屋を再起動したとき、自動的に training が再実行されるのは意図しない動作。`.done` チェックが必要。

---

## Don't Hand-Roll

| 問題 | 作らないこと | 使うもの | 理由 |
|------|-------------|----------|------|
| Mr. ポポのヒアリングロジック | カスタムインタビュースクリプト | spirit-room-manager/skills/MR_POPO.md + claude | 完全実装済み |
| 修行ループの冪等制御 | 独自の状態管理 | .prepared / .done フラグファイル | Phase 2 で動作実証済み |
| Python パッケージインストール | 独自インストーラー | pip3 + --break-system-packages | root コンテナで十分 |
| コンテナ内認証 | 独自トークン管理 | spirit-room-auth Docker volume | Phase 2 で認証共有実証済み |

---

## Common Pitfalls

### Pitfall 1: pip install が externally-managed-environment で失敗する

**What goes wrong:** PHASE 1 で Claude Code が `pip install langgraph` を実行すると、Ubuntu 24.04 の PEP 668 制約により `error: externally-managed-environment` が発生。`.prepared` フラグが作成されず PHASE 1 がループし続ける。

**Why it happens:** Ubuntu 24.04 はシステム Python パッケージの保護のため、デフォルトで pip による system-wide インストールを禁止している。

**How to avoid:** `catalog.md` の「追加ツールのインストール」セクションを以下のように修正する:
```
pip3 install <package> --break-system-packages
```

**Warning signs:** PHASE 1 ログに `externally-managed-environment` エラーが繰り返し現れ、.prepared が作成されない。

[VERIFIED: docker run でエラーを実測確認。--break-system-packages で解決確認済み]

### Pitfall 2: entrypoint.sh 変更後の再ビルド忘れ

**What goes wrong:** `spirit-room/base/entrypoint.sh` を変更してもイメージが古いまま。`spirit-room open` で起動するコンテナは変更前の entrypoint.sh で動作し、MISSION.md を自動検知しない。

**Why it happens:** `entrypoint.sh` は `COPY` 命令でイメージに焼き込まれている。ホスト側ファイルの変更はマウントされていないので反映されない。

**How to avoid:** `entrypoint.sh` を変更したら必ず `./build-base.sh` を実行する。

**Warning signs:** `spirit-room open` 後に tmux training ペインが "start-training で修行開始" を表示する（自動起動しない）。

[VERIFIED: Phase 2 Plan 03 で start-training.sh の同様問題を経験済み]

### Pitfall 3: spirit-room CLI が PATH に未インストール

**What goes wrong:** `spirit-room open` コマンドが "command not found" で失敗。Mr. ポポが `spirit-room open ~/projects/xxx` を実行できない。

**Why it happens:** `spirit-room` スクリプトはリポジトリ内にあるだけで `/usr/local/bin` への設置が行われていない（実測確認）。

**How to avoid:** 先にインストール: `sudo cp spirit-room/spirit-room /usr/local/bin/spirit-room && sudo chmod +x /usr/local/bin/spirit-room`

**Warning signs:** `which spirit-room` が "spirit-room not in PATH" を返す。

[VERIFIED: which spirit-room → not found]

### Pitfall 4: ~/projects/ が存在しない

**What goes wrong:** Mr. ポポが `mkdir -p ~/projects/langgraph-poc` を実行しても、`spirit-room open ~/projects/langgraph-poc` が失敗する可能性。あるいは MR_POPO.md の手順どおりに動かない。

**Why it happens:** `~/projects/` は明示的に作成が必要なディレクトリ。ホスト環境に存在しない（実測確認）。

**How to avoid:** E2E 検証前に `mkdir -p ~/projects` を実行。Mr. ポポが `mkdir -p ~/projects/[名前]` を実行するので、親ディレクトリが存在すれば問題ない。

[VERIFIED: ls ~/projects → NOT EXISTS]

---

## Code Examples

### entrypoint.sh の修正パターン（E2E-02 対応）

```bash
# Source: 現行 spirit-room/base/entrypoint.sh + 変更案
# trainingペインの部分を以下に置き換える

if [ -f /workspace/MISSION.md ] && [ ! -f /workspace/.done ]; then
    tmux send-keys -t "$SESSION:training" "start-training" C-m
else
    tmux send-keys -t "$SESSION:training" \
        "echo '部屋[$ROOM_NAME] 準備完了 | start-training で修行開始 | status で確認'" C-m
fi
```

### catalog.md の修正パターン（E2E-03 対応）

```markdown
## 追加ツールのインストール
必要であれば以下でインストールできる。インストールしたものはcatalog.mdへの追記を推奨。

```bash
# Python パッケージ（Ubuntu 24.04 では --break-system-packages が必要）
pip3 install <package> --break-system-packages

# または venv を使う場合
python3 -m venv /workspace/.venv
source /workspace/.venv/bin/activate
pip install <package>
```
```

### spirit-room CLI インストール

```bash
# ホスト側で一度だけ実行
sudo cp /home/parallels/workspaces/spirit-room-full/spirit-room/spirit-room /usr/local/bin/spirit-room
sudo chmod +x /usr/local/bin/spirit-room

# 確認
spirit-room list
```

### E2E-03 用サンプル MISSION.md（LangGraph）

```markdown
# MISSION: LangGraph - シンプルな状態遷移グラフ POC

## 目的
LangGraph の基本的な StateGraph と状態遷移を理解する

## 完了条件（全て満たすまで繰り返せ）
- [ ] `cd /workspace && python3 test_graph.py` が exit code 0 で終了する
- [ ] `/workspace/README.md` に学習サマリーが書かれている

## 実装スコープ
- StateGraph を使ったシンプルな 2 ノードのグラフを実装する
- mock LLM（openai API なし）で動作すること

## 制約
- 外部 API: 使用しない（モック使用）
- 言語: Python 3.x
- 成果物は /workspace/ 配下
```

---

## Runtime State Inventory

> Phase 3 はコード変更と E2E 検証が主目的。ただし既存のコンテナ・ボリューム状態がある。

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | spirit-room-auth volume: 有効な credentials 入り（実測確認）| なし（そのまま使用） |
| Live service config | spirit-room-auth-temp コンテナが port 2299 で起動中（Phase 2 の残骸） | `docker rm -f spirit-room-auth-temp` で削除 |
| OS-registered state | spirit-room CLI が /usr/local/bin に未登録 | sudo cp + chmod でインストール |
| Secrets/env vars | ~/.claude.json がホストに存在（spirit-room open がマウントする） | なし（使用継続） |
| Build artifacts | spirit-room-base:latest は 2 時間前にビルド済み。entrypoint.sh 変更後は再ビルド要 | build-base.sh 実行 |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `spirit-room` CLI | E2E-01, E2E-02, E2E-03 | ✗ | — | `sudo cp spirit-room/spirit-room /usr/local/bin/` |
| Docker | 全 E2E | ✓ | 29.4.0 | なし（必須） |
| `spirit-room-base:latest` | E2E-02, E2E-03 | ✓ | 2h 前ビルド | `./build-base.sh` |
| `spirit-room-auth` volume | E2E-02, E2E-03 | ✓ | credentials 入り | `spirit-room auth` |
| `claude` (host) | E2E-01 (Mr. ポポ起動) | ✓ | 2.1.107 | — |
| `~/projects/` | E2E-01 (MISSION.md 配置先) | ✗ | — | `mkdir -p ~/projects` |
| `python3` (host) | 不要（コンテナ内のみ使用） | ✓ | 3.12.3 | — |

**Missing dependencies with no fallback:**
- なし

**Missing dependencies with fallback:**
- `spirit-room` CLI: `/usr/local/bin` 未登録 → `sudo cp` でインストール
- `~/projects/`: 未作成 → `mkdir -p ~/projects`

[VERIFIED: which spirit-room, ls ~/projects, docker images, docker volume ls, claude --version]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | entrypoint.sh に MISSION.md 自動検知を追加するアプローチが E2E-02 の「automatically」の意図と合致する | Architecture Patterns | 別の自動起動アプローチ（spirit-room open のオプション追加等）が求められる場合、entrypoint.sh の変更だけでは不十分 |
| A2 | E2E-03 のテストフレームワークとして LangGraph が適切（小規模で外部 API 不要の POC が作れる） | Code Examples | LangGraph が想定外に複雑でテスト完走に時間がかかる場合、simpler なフレームワーク（requests + FastAPI 等）に変更する |

---

## Open Questions

1. **E2E-02: 「automatically」の解釈**
   - What we know: ROADMAP には "training loop launches automatically" とある
   - What's unclear: entrypoint.sh で自動実行 vs spirit-room open コマンドのオプション追加のどちらが意図か
   - Recommendation: entrypoint.sh での MISSION.md 検知が最もシンプルで設計哲学（bash のみ）に合致する。A1 として確認が必要な場合はユーザーに確認する

2. **E2E-03: テスト用フレームワークの選定**
   - What we know: REQUIREMENTS.md に「LangGraph 等」とある
   - What's unclear: LangGraph が適切か、simpler なものでいいか
   - Recommendation: 外部 API 不要の mock LLM で動く LangGraph サンプルを使う。失敗した場合は requests + httpx 等のシンプルな Python ライブラリに切り替える

---

## Sources

### Primary (HIGH confidence)
- 実測: `which spirit-room` → not found [VERIFIED]
- 実測: `ls ~/projects` → NOT EXISTS [VERIFIED]
- 実測: `docker run --rm --entrypoint pip3 spirit-room-base:latest install requests --break-system-packages` → Successfully installed [VERIFIED]
- 実測: `docker run --rm --entrypoint pip3 spirit-room-base:latest install langgraph --break-system-packages --dry-run` → Collecting langgraph 1.1.6 [VERIFIED]
- 実測: `docker run --rm --entrypoint claude spirit-room-base:latest auth status --text` → Login method: Claude Max Account [VERIFIED]
- 実測: `docker images spirit-room-base:latest` → 存在確認 [VERIFIED]
- 実測: `docker volume ls --filter name=spirit-room` → spirit-room-auth 存在 [VERIFIED]
- コード精査: `spirit-room/base/entrypoint.sh` → trainingペインは手動案内のみ [VERIFIED]
- コード精査: `spirit-room/base/catalog.md` → pip の --break-system-packages 注記なし [VERIFIED]
- コード精査: `spirit-room-manager/skills/MR_POPO.md` → 完全実装済み [VERIFIED]
- Phase 2 Plan 03 SUMMARY: entrypoint.sh 変更には再ビルドが必要という知見 [CITED]

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md` — フェーズ要件と現状の把握
- `.planning/phases/02-auth-training-loop/02-03-SUMMARY.md` — CLAUDE_CODE_BUBBLEWRAP=1 等の Phase 2 成果の継承

---

## Metadata

**Confidence breakdown:**
- 環境状態（インストール済み/未インストール）: HIGH — 実測確認
- entrypoint.sh 変更アプローチ: HIGH — コード精査と要件の照合による
- pip --break-system-packages 必要性: HIGH — コンテナ内で実測確認
- E2E-03 テスト選定: MEDIUM — LangGraph dry-run 成功確認のみ、完走は未確認

**Research date:** 2026-04-14
**Valid until:** 2026-07-14（bash + Docker は安定。Claude Code CLI は更新頻度高いため 90 日）
