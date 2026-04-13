# 精神と時の部屋

## What This Is

DockerコンテナをAI修行の場として使い、AIエージェント（Claude Code / opencode）が自律的にフレームワークのPOCを実装するサンドボックス環境。Mr.ポポ（管理AI）がユーザーにヒアリングしてMISSION.mdを生成し、部屋を起動する。AIが繰り返し「準備 → 実装」フェーズを回し、人手なしにPOCを完成させる。

## Core Value

Mr.ポポにフレームワーク名と目的を伝えたら、Claude Codeが自律的にPOCを実装して動くところまで完成させる。

## Requirements

### Validated

- ✓ Dockerベースイメージ定義（Dockerfile + entrypoint.sh） — existing
- ✓ ホストCLI（open / enter / list / close / logs / auth） — existing
- ✓ 2フェーズ修行ループ（start-training.sh / .prepared / .done フラグ） — existing
- ✓ 認証ボリューム共有（spirit-room-auth で全部屋を横断） — existing
- ✓ Mr.ポポヒアリングスキル（MR_POPO.md） — existing

### Active

- [ ] `./build-base.sh` がエラーなく完了し、spirit-room-base:latest イメージが生成される
- [ ] `spirit-room open` でコンテナが起動し、SSH接続・tmux 3ペイン・Redis が正常動作する
- [ ] `claude auth login` のDevice Flowがコンテナ内で完了できる（または代替認証方式が機能する）
- [ ] `start-training.sh` が実行され、PHASE1→PHASE2 のループが回る
- [ ] Mr.ポポフローでMISSION.mdを生成し、`spirit-room open` → 修行ループ起動まで一気通貫で動く

### Out of Scope

- モニタリングWeb UI（spirit-room monitor）— コア動作優先、後回し
- ポートの決定論的計算（フォルダ名ハッシュ）— 現在のauto-port選択で十分
- opencode サポート検証 — まずClaudeで動かすことを優先

## Context

既存コードはほぼ完成しているが、実際に動かしたことがない状態。HANDOVER.mdが指摘する3つのつまずきポイントが存在する：
1. `claude auth login` のDevice FlowがDockerコンテナ内で動くか（ブラウザ不在問題）
2. `claude -p` の `--allowedTools` フラグの正確なオプション名（バージョン依存）
3. opencode のインストールパッケージ名（`opencode-ai` が正しいか未確認）

コードは spirit-room/ と spirit-room-manager/ の2ディレクトリ構成。spirit-room-manager はスタンドアロンの管理AI（Mr.ポポ）として機能し、独自のCLAUDE.mdを持つ。

## Constraints

- **Tech Stack**: bash + Docker — Node.js/Python等は追加しない。コアはシェルスクリプトのみ
- **Simplicity**: 実装前に大量のファイルを作らない。動いてから育てる
- **Naming**: Dragon Ball世界観（Mr.ポポ、精神と時の部屋）を守る

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| フォルダ = 部屋 | ディレクトリ名がそのままコンテナ名になる直感的な設計 | — Pending |
| ループ制御はbash、判断はClaude | Claude Codeの制御フロー記述は信頼性が低いため | — Pending |
| 認証ボリューム共有 | 部屋ごとに認証し直す手間を排除 | — Pending |

---
*Last updated: 2026-04-13 after initialization*

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state
