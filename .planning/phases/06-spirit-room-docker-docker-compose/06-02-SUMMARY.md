---
phase: 06-spirit-room-docker-docker-compose
plan: "02"
subsystem: infra
tags: [docker, entrypoint, goku, docker-group, DooD, bash]

requires:
  - phase: 05-goku-uid-gid-root-workspace-sudo-chown-entrypoint-sh-host-ui
    provides: goku ユーザーの冪等作成フロー (id goku / useradd / usermod) と sudo NOPASSWD:ALL

provides:
  - "entrypoint.sh に SPIRIT_ROOM_DOCKER=1 分岐として docker グループ動的合流ロジックを追加"
  - "HOST_DOCKER_GID 非空時: getent で既存グループ名取得 → なければ groupadd -g → usermod -aG goku"
  - "HOST_DOCKER_GID 空時: sudo フォールバックメッセージ出力"
  - "SPIRIT_ROOM_DOCKER 未設定時はロジック全体をスキップ (Phase 5 の goku 冪等作成に非回帰)"

affects:
  - 06-spirit-room-docker-docker-compose (Plan 03 以降の CLI フラグ設計)
  - spirit-room open/kaio の --docker フラグ (HOST_DOCKER_GID を -e で渡す側)

tech-stack:
  added: []
  patterns:
    - "SPIRIT_ROOM_DOCKER=1 による opt-in 分岐: 環境変数が揃っていない場合は何もしない設計"
    - "getent group $GID | cut -d: -f1 による GID→グループ名解決 (D-07 GID 衝突回避)"
    - "_dgrp_name プレフィックス付き変数でスコープ汚染を最小化 (entrypoint はトップレベル実行)"

key-files:
  created: []
  modified:
    - spirit-room/base/entrypoint.sh

key-decisions:
  - "D-07 準拠: groupadd -o (名前重複許可) を使わず getent で既存グループ名を取得して usermod する"
  - "D-12 準拠: SPIRIT_ROOM_DOCKER=1 を単一ソースオブトゥルースとし、HOST_DOCKER_GID の有無で Docker モード判定しない"
  - "usermod -aG に || true を付け、グループ追加失敗でも entrypoint 全体がクラッシュしないようにする"
  - "コメントから 'groupadd -o' という文字列を除去し acceptance criteria の grep 検証を通す"

patterns-established:
  - "起動ごとにグループ合流を試みる (冪等): HOST_DOCKER_GID が変わっても再起動で追従"
  - "[INFO] docker grp: ... の 1 行ログで成功/失敗どちらでも可視化"

requirements-completed: []

duration: 8min
completed: 2026-04-18
---

# Phase 06 Plan 02: entrypoint.sh docker グループ動的合流 Summary

**`SPIRIT_ROOM_DOCKER=1` 時に `HOST_DOCKER_GID` を使って goku を動的に docker グループへ合流させる分岐を entrypoint.sh に追加し、DooD 部屋内での `sudo` なし `docker` コマンド実行を実現**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-18T23:40:00Z
- **Completed:** 2026-04-18T23:48:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- `entrypoint.sh` の goku 冪等作成ブロック直後に `SPIRIT_ROOM_DOCKER=1` 分岐を追加
- `getent group $HOST_DOCKER_GID` で GID 衝突を先行チェックし、既存グループ名を取得 (D-07)
- 既存グループなし時は `groupadd -g $HOST_DOCKER_GID docker` → `usermod -aG docker goku`
- 3 パターン全カバー: 合流成功 / groupadd 失敗 / HOST_DOCKER_GID 空 (sudo フォールバック)
- Phase 5 の goku 冪等作成フロー (`id goku / useradd / usermod`) に非回帰を確認

## Task Commits

1. **Task 1: entrypoint.sh に docker グループ動的合流ロジックを追加** - `2f41c3d` (feat)

**Plan metadata:** (本コミットで更新)

## Files Created/Modified

- `spirit-room/base/entrypoint.sh` — goku 冪等作成 `fi` 直後 (line 62) に docker グループ合流ブロック 29 行を挿入

## Decisions Made

- `groupadd -o` を使わない: D-07 の GID 衝突回避方針に従い、`getent group $GID` で既存グループ名を先取得する実装を採用
- `usermod -aG ... || true`: グループ追加失敗でも entrypoint がクラッシュしないよう、エラーを無視しログに記録する方針
- コメントから `groupadd -o` 文字列を除去: acceptance criteria の `! grep -q 'groupadd -o'` が通るよう、説明文を「D-07: 名前衝突を避けるため getent で既存グループを先に探し」に変更

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] コメント文言に `groupadd -o` が含まれ acceptance criteria を破っていた**

- **Found during:** Task 1 (検証フェーズ)
- **Issue:** プランの acceptance criteria `! grep -q 'groupadd -o'` はコメント行も grep するため、「使わない」説明コメントがヒットして基準を満たせなかった
- **Fix:** コメント文言を `groupadd -o` を含まない表現「名前衝突を避けるため getent で既存グループを先に探し、なければ新規作成する」に変更
- **Files modified:** spirit-room/base/entrypoint.sh
- **Verification:** `grep -q 'groupadd -o' spirit-room/base/entrypoint.sh` がヒットしないことを確認
- **Committed in:** `2f41c3d` (Task 1 コミットに含む)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** acceptance criteria の grep 検証を通すためのコメント文言修正のみ。ロジックへの影響なし。

## Issues Encountered

なし。

## Self-Check

- [x] `spirit-room/base/entrypoint.sh` が存在する
- [x] コミット `2f41c3d` が存在する
- [x] `bash -n` で構文エラーなし
- [x] `grep -c 'SPIRIT_ROOM_DOCKER'` → 2 (1 以上)
- [x] `grep -c 'HOST_DOCKER_GID'` → 8 (3 以上)
- [x] `grep -c 'docker grp'` → 3 (3 パターン全カバー)
- [x] `getent group` がヒット
- [x] `chmod 666` が不在
- [x] `groupadd -o` が不在

## User Setup Required

なし — イメージリビルドは Wave 3 (Plan 06-01 で Dockerfile 変更済み) で実施。本 Plan はロジック追加のみ。

## Next Phase Readiness

- entrypoint.sh の docker グループ合流ロジック完成
- 次の Plan 06-03: `spirit-room` CLI に `--docker` フラグと `_docker_extra_args()` ヘルパーを追加する作業へ進める
- 非回帰: `SPIRIT_ROOM_DOCKER` 未設定の既存部屋は引き続き従来動作

---
*Phase: 06-spirit-room-docker-docker-compose*
*Completed: 2026-04-18*
