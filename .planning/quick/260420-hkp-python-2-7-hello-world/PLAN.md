---
quick_id: 260420-hkp
slug: python-2-7-hello-world
description: 胡蝶の夢モード (--kochou) で Python 2.7 環境を Docker Compose で作成し Hello World を動かす MISSION.md 指示書を作成
date: 2026-04-20
timestamp: 2026-04-20T03:39:15.320Z
---

# Quick Task: 胡蝶の夢モード Python 2.7 Hello World 指示書

## 目的

Phase 6 で追加された `--kochou` フラグ (胡蝶の夢モード、旧 `--docker`) の検証・デモ用の MISSION.md を作成する。

胡蝶の夢モードは「部屋の中からホスト Docker を借りて Compose で兄弟コンテナを立てる」DooD 方式。この能力を最小構成で示すため、Ubuntu 24.04 ベースの部屋では持っていない Python 2.7 環境を、あえて Docker Compose で立てて動かす題材を選ぶ。

## 成果物

- `BRIEF.md` — **Mr.ポポ に渡す仕様書 (事前回答つき)**
  - Step 0 (モード選択) から Step 3-c (胡蝶の夢モード) まで全てに先回り回答
  - Mr.ポポ はこの仕様書を見ながら `AskUserQuestion` を回して確認 → MISSION.md 生成 → `spirit-room open --kochou` 実行
  - 部屋の Claude 向けの MISSION.md は Mr.ポポ が生成する (この quick task では作らない)

## 使い方 (想定)

```bash
# 新セッションで Mr.ポポ を起動
cd spirit-room-manager
claude
# Mr.ポポ の挨拶 + Step 0 が出たら、BRIEF.md の該当セクションを順に貼りながら進める
```

## スコープ外

- **MISSION.md の作成は含まない** (Mr.ポポ の仕事)
- 実走検証も含まない (Mr.ポポ が部屋を起動した後、ユーザーが `spirit-room logs` / `enter` で確認)

## 経緯

初版では直接 MISSION.md を手書きしてしまった (commit 5ce1e97)。ユーザー指摘により「Mr.ポポ のヒアリングを経て MISSION.md が生成される」本来の流れに合わせて BRIEF.md (Mr.ポポ 向け仕様書) に変更。
