---
phase: 03-end-to-end-flow
plan: 01
subsystem: infra
tags: [docker, bash, spirit-room, entrypoint, pip, ubuntu-24-04]

# Dependency graph
requires:
  - phase: 02-auth-training-loop
    provides: spirit-room-base:latest イメージ (entrypoint.sh/catalog.md の変更ベース)
provides:
  - spirit-room CLI が ~/.local/bin/spirit-room に PATH インストール済み
  - ~/projects/ ディレクトリが存在
  - entrypoint.sh が MISSION.md 存在時に start-training を自動起動する条件分岐を持つ
  - catalog.md が pip3 install --break-system-packages を明記
  - spirit-room-base:latest がこれら変更を焼き込んだ状態で再ビルド済み
affects:
  - 03-02 (Mr.ポポ E2E 実行)
  - 03-end-to-end-flow 全体

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MISSION.md 存在検知 + .done フラグによる条件分岐で自動起動と多重実行防止を両立"
    - "pip3 install --break-system-packages で Ubuntu 24.04 の PEP 668 制約を回避"

key-files:
  created: []
  modified:
    - spirit-room/base/entrypoint.sh
    - spirit-room/base/catalog.md

key-decisions:
  - "spirit-room CLI を /usr/local/bin ではなく ~/.local/bin に配置 — sudoパスワード不要で同等の PATH アクセスを実現"
  - "entrypoint.sh の自動起動条件に .done チェックを追加 — 修行完了済み部屋の再起動時に多重実行を防止"
  - "catalog.md に venv 代替手段も併記 — --break-system-packages を使えない状況への対応"

patterns-established:
  - "Pattern 1: entrypoint.sh でコンテナ起動時に MISSION.md を検知して start-training を自動実行"
  - "Pattern 2: .done フラグで冪等性を確保（修行完了済みは自動起動しない）"
  - "Pattern 3: pip3 install <pkg> --break-system-packages を Ubuntu 24.04 コンテナの標準手順とする"

requirements-completed: [E2E-02, E2E-03]

# Metrics
duration: 30min
completed: 2026-04-14
---

# Phase 03 Plan 01: インフラ前提整備 Summary

**spirit-room CLI をホスト PATH に配置、entrypoint.sh に MISSION.md 自動検知ロジックを追加、catalog.md に pip3 --break-system-packages を明記し、spirit-room-base:latest に焼き込み再ビルド完了**

## Performance

- **Duration:** 約 30 min
- **Started:** 2026-04-14T08:40:00Z
- **Completed:** 2026-04-14T09:10:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- spirit-room CLI を `~/.local/bin/spirit-room` に設置し、任意ディレクトリから `spirit-room` コマンドが実行可能になった
- `entrypoint.sh` に MISSION.md 検知 + `.done` フラグチェックによる条件分岐を追加し、コンテナ起動時に `start-training` が自動実行されるようになった
- `catalog.md` の pip インストール手順を Ubuntu 24.04 対応の `pip3 install --break-system-packages` に更新し、PHASE 1 の PEP 668 エラーを解消
- `spirit-room-base:latest` を再ビルドし、上記変更をイメージに焼き込んだ（ビルド時刻: 2026-04-14T18:09:34+09:00）

## Task Commits

各タスクをアトミックにコミット:

1. **Task 1: spirit-room CLI インストール + ~/projects 作成 + entrypoint.sh と catalog.md 修正** - `98bff44` (feat)
2. **Task 2: spirit-room-base:latest 再ビルド** - ビルドのみ (新規ファイル変更なし、Task 1 コミットに含む)

**Plan metadata:** (SUMMARY.md コミット時に確定)

## Files Created/Modified

- `spirit-room/base/entrypoint.sh` - MISSION.md 自動検知 + .done チェックによる start-training 自動起動ロジックを追加
- `spirit-room/base/catalog.md` - 追加ツールインストール節を pip3 --break-system-packages と venv に更新
- `~/.local/bin/spirit-room` - spirit-room CLI のホスト PATH インストール（リポジトリ外）

## Decisions Made

- **spirit-room CLI を `~/.local/bin/` に配置:** sudo パスワードが対話的に求められ、自動化環境では `/usr/local/bin/` への書き込みが不可能だった。`~/.local/bin/` は既に PATH に含まれており、同等の機能を提供する。Rule 3 (blocking issue) として自動対処。
- **.done フラグチェックを条件分岐に追加:** 修行完了済みの部屋を再起動した際に `start-training` が自動実行されると多重実行が発生する。プラン仕様どおりに `.done` の非存在チェックを追加。
- **venv 手順も catalog.md に併記:** `--break-system-packages` が使えない状況（将来的なポリシー変更等）への対応として、venv 代替手段も明記した。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] spirit-room CLI を /usr/local/bin の代わりに ~/.local/bin にインストール**
- **Found during:** Task 1 (spirit-room CLI インストール)
- **Issue:** `sudo cp /usr/local/bin/spirit-room` が sudo パスワード入力を要求し、非対話的環境では実行不可
- **Fix:** `~/.local/bin/spirit-room` にコピー。同ディレクトリは既に PATH に含まれており、`which spirit-room` で正常に解決される
- **Files modified:** `~/.local/bin/spirit-room` (リポジトリ外)
- **Verification:** `which spirit-room` → `/home/parallels/.local/bin//spirit-room`
- **Committed in:** 98bff44 の対象外 (PATH 外ファイルのため)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking)
**Impact on plan:** インストール先が変わっただけで機能は同等。`which spirit-room` は PATH から正常に解決される。

## Issues Encountered

- `sudo cp` が対話的パスワード入力を要求 → `~/.local/bin/` への代替インストールで解決
- Task 2 ビルド検証時に `/room/entrypoint.sh` ではなく `/entrypoint.sh` が正しいパスと判明 (Dockerfile の COPY 先が root)

## User Setup Required

None - spirit-room CLI は `~/.local/bin/spirit-room` に自動インストール済み。新しいシェルセッションでも既に PATH に含まれている。

## Next Phase Readiness

- spirit-room CLI がホスト PATH から実行可能
- ~/projects ディレクトリが存在し、Mr. ポポが MISSION.md を配置できる
- コンテナ起動時に MISSION.md があれば start-training が自動実行される
- pip3 install コマンドが Ubuntu 24.04 で成功する
- 次ステップ (03-02): Mr. ポポを実際に起動し、LangGraph MISSION.md で E2E 完走を検証する

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `spirit-room/base/entrypoint.sh` exists | FOUND |
| `spirit-room/base/catalog.md` exists | FOUND |
| `03-01-SUMMARY.md` exists | FOUND |
| `~/.local/bin/spirit-room` exists | FOUND |
| `~/projects` directory exists | FOUND |
| commit `98bff44` exists | FOUND |
| MISSION.md check in image `/entrypoint.sh` | FOUND |
| `break-system-packages` in image `/room/catalog.md` | FOUND |

---
*Phase: 03-end-to-end-flow*
*Completed: 2026-04-14*
