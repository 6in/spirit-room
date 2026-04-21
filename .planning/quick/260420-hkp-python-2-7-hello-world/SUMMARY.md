---
quick_id: 260420-hkp
slug: python-2-7-hello-world
completed: 2026-04-20
status: complete
---

# Quick Task SUMMARY — 胡蝶の夢モード Python 2.7 Hello World 仕様書 (Mr.ポポ 向け)

## 実施内容

Phase 6 の `--kochou` (胡蝶の夢モード) を実演する題材として、Mr.ポポ に渡す「事前回答つき仕様書」(BRIEF.md) を作成した。

**経緯**: 初版では部屋の Claude 向けの MISSION.md を手書きしてしまった (commit 5ce1e97)。しかし本来の Spirit Room の流れは `spirit-room-manager` で Mr.ポポ がヒアリング (Step 0〜3) を経て MISSION.md を生成するもの。ユーザー指摘を受けて成果物を **Mr.ポポ のヒアリングに先回り回答する仕様書 (BRIEF.md)** に差し替えた。旧 MISSION.md は削除。

## 成果物

- `.planning/quick/260420-hkp-python-2-7-hello-world/PLAN.md` — Quick タスクの計画
- `.planning/quick/260420-hkp-python-2-7-hello-world/BRIEF.md` — **Mr.ポポ 向け仕様書 (事前回答つき)**

## BRIEF.md の要点

| 項目 | 事前回答 |
|------|----------|
| Step 0 モード | 精神と時の部屋 (POC 速攻型) |
| Step 1-a フレームワーク | 「その他」→ Python 2.7 + Docker Compose (胡蝶の夢モード) |
| Step 1-b 理解したい粒度 | 動作確認 |
| Step 1-c 調査観点 | 設計思想 + API の癖 |
| Step 2 完了条件 | 動けばいい (Hello from Python 2.7! が出ればよい、ただし README に「普通の部屋との違い」5行は必須) |
| Step 3-a 外部 API | 使わない |
| Step 3-b バージョン | python:2.7 (Docker Hub 公式) + catalog.md 胡蝶の夢セクション参照 |
| Step 3-c 胡蝶の夢モード | **はい (--kochou で起動)** |

加えて Mr.ポポ への追加指示として、MISSION.md 生成時に含めるべき 6 点 (前提チェック / compose.yaml 制約 / Python 2 構文 / sudo フォールバック / Python 3 SyntaxError ボーナス検証 / README 5 行) を明記。

提案フォルダ名: `python27-kochou-hello`

## 使い方

```bash
# 新セッションで Mr.ポポ を起動
cd spirit-room-manager
claude
# 挨拶 + Step 0 が出たら BRIEF.md の事前回答セクションを順に貼る
# Mr.ポポ が MISSION.md を生成 → spirit-room open --kochou ~/projects/python27-kochou-hello
```

## 関連

- Phase 6 (✓ 2026-04-19): spirit-room --docker / --kochou フラグ (Docker Compose 対応)
- Mr.ポポ のヒアリング手順: `spirit-room-manager/skills/MR_POPO.md`
- 胡蝶の夢モード catalog: `spirit-room/base/catalog.md:66-139`

## Next

- ユーザーが別セッションで Mr.ポポ を起動し、BRIEF.md を片手にヒアリングを通過 → MISSION.md 生成 → 部屋起動
- Phase 6 の E2E で済んだ検証 (Plan 06-05) とは別の実地題材になる (部屋に入っていないランタイムを兄弟コンテナで借りる典型シナリオ)
