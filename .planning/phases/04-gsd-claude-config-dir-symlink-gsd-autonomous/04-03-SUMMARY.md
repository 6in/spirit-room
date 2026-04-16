---
phase: 04-gsd-claude-config-dir-symlink-gsd-autonomous
plan: 03
subsystem: spirit-room/base/scripts
tags: [template, kaio, gsd, mission]
requires: []
provides:
  - KAIO-MISSION.md.template (界王星モードの修行課題テンプレート)
affects:
  - spirit-room-manager (界王星モード選択時のヒアリング雛形として参照)
  - start-training-kaio.sh (生成された KAIO-MISSION.md を /gsd-new-project の事前回答に流用)
tech-stack:
  added: []
  patterns:
    - Markdown テンプレート (既存 MISSION.md.template と対比される second template)
    - GSD /gsd-new-project → /gsd-autonomous 非対話チェーンの固定指示を内包
key-files:
  created:
    - spirit-room/base/scripts/KAIO-MISSION.md.template
  modified: []
decisions:
  - 既存 MISSION.md.template は一切触らず別ファイルとして新規作成 (POC速攻型と界王星モードを明示的に分離)
  - 成功条件セクションで「良い例」「悪い例」を併記し、曖昧基準を禁じる
  - GSD への固定指示ブロックを末尾に置き、Mr.ポポが書き換えない前提とした
metrics:
  duration: ~5min
  tasks: 1
  files: 1
  completed: 2026-04-16
---

# Phase 4 Plan 03: KAIO-MISSION.md.template 作成 Summary

**One-liner:** 界王星モード向けの GSD 駆動本格開発テンプレートを新設し、要件粒度ヒント・フェーズ分割示唆・テスト可能な成功条件の3追加項目を固定化した。

## 背景

Phase 4 (界王星モード) では、既存の POC 速攻型 `MISSION.md.template` とは別に、GSD (`/gsd-new-project` → `/gsd-autonomous`) で本格的な段階開発を回すための専用テンプレートが必要。CONTEXT.md の specifics 節で「KAIO-MISSION.md テンプレート」として挙げられた 3 つの追加項目 (要件の粒度 / フェーズ分割 / 成功条件の具体性) をファイル化する plan。

## 実装内容

### Task 1: KAIO-MISSION.md.template 新規作成

- **ファイル**: `spirit-room/base/scripts/KAIO-MISSION.md.template` (111 行)
- **コミット**: `26aaea5` feat(04-03): add KAIO-MISSION.md.template for 界王星 mode
- **構成**:
  - 修行スタイル (界王星モードと GSD チェーンの位置づけを明示)
  - プロジェクトの目的 / 背景・達成したい価値
  - 機能要件 (大まか) + **要件の粒度ヒント** (大きすぎ/ちょうどいい/細かすぎ の3段例)
  - **フェーズ分割の示唆** (任意・3フェーズ例 + 書き方のコツ)
  - **成功条件 (テスト可能な形で)** — 良い例/悪い例を併記して曖昧基準を明示的に禁止
  - 制約 / 参考情報
  - GSD への固定指示 (書き換え禁止ブロック)
- **既存 MISSION.md.template は非改変** (`git status` で確認済、`MISSION.md.template` は staged にも unstaged にも出ない)

## 設計判断

1. **別ファイルとして分離**: POC 速攻型と界王星モードは対象領域も進行方式も違うので、1 つのテンプレートに分岐条件を持たせず、物理的に別ファイルにした。Mr.ポポのモード分岐と対称。
2. **成功条件の「悪い例」併記**: GSD verify 段階で自動判定できない曖昧基準 (「いい感じに動く」「UX が良い」) を明文で禁止。Plan 04 以降の Mr.ポポ界王星ヒアリングがこれを守らせる前提。
3. **GSD への固定指示を末尾に配置**: `start-training-kaio.sh` から `claude -p` に渡されたとき、エージェントが最後に読むブロックに非対話ルール (AskUserQuestion 禁止 / デフォルト選択 / `.done` 生成) を置き、行動規範として効かせる。

## 検証結果

```bash
$ wc -l spirit-room/base/scripts/KAIO-MISSION.md.template
111  # >= 40 OK (目安 100〜130 内)

$ for kw in '要件の粒度' 'フェーズ分割' '成功条件' '界王星' 'gsd-new-project' 'gsd-autonomous'; do
    grep -q "$kw" spirit-room/base/scripts/KAIO-MISSION.md.template && echo "OK: $kw"
  done
OK: 要件の粒度
OK: フェーズ分割
OK: 成功条件
OK: 界王星
OK: gsd-new-project
OK: gsd-autonomous

$ git diff HEAD~1 spirit-room/base/scripts/MISSION.md.template
# (空 — 既存ファイル非改変)
```

Plan 駆動の automated verify ブロックに記載された全条件をクリア。

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

なし。テンプレートは雛形なのでプレースホルダ `[...]` は意図的に残しているが、これは Mr.ポポがインスタンス化時に埋める設計上の穴であり、スタブではない。

## 次の plan への引き継ぎ

- Plan 04 (Mr.ポポの界王星モード分岐) はこのテンプレートを参照してヒアリング項目を組み立てる
- Plan 05 (`start-training-kaio.sh`) は生成された `/workspace/KAIO-MISSION.md` を `claude -p` プロンプトに埋め込む
- 成功条件セクションの「良い例」形式は Plan 05 でも再利用できる

## Self-Check: PASSED

- FOUND: spirit-room/base/scripts/KAIO-MISSION.md.template
- FOUND: commit 26aaea5
- VERIFIED: 既存 `spirit-room/base/scripts/MISSION.md.template` は未変更 (git status 確認)
- VERIFIED: 111 行 (目安 100〜130 内、min_lines=40 以上)
- VERIFIED: 必須キーワード 6 種すべて含有
