---
created: 2026-04-19T00:00:00.000Z
title: Mr.ポポに --docker フラグ判定を追加
area: tooling
files:
  - spirit-room-manager/skills/MR_POPO.md
  - spirit-room-manager/CLAUDE.md
---

## Problem

Phase 6 で `spirit-room open --docker` フラグを CLI に追加したが、Mr.ポポ (`spirit-room-manager/`) は常に `--docker` 無しで部屋を起動する。

フロー:
```
User → Mr.ポポ (ヒアリング) → MISSION.md 生成 → spirit-room open [folder]
                                                       ^^^^^^^^^^^^^^^^^ ← 常に --docker なし
```

結果として、ユーザーが「Docker Compose ベースの POC をやりたい」とヒアリング時に言っても、Claude が部屋内で `docker compose up` を叩けない。Phase 6 で DooD 機構は作ったのに Mr.ポポ経由では使えない状態。

Phase 6 の CONTEXT.md `<deferred>` に「Mr.ポポが MISSION 内容から --docker を自動判定」として明示的に後送り済み。

## Solution

2 通りのアプローチ候補:

**案 A (簡単): ヒアリング Step に 1 問追加**

`spirit-room-manager/skills/MR_POPO.md` の interview フェーズ (Step 1 フレームワーク選定の後あたり) に:

```
Q: compose.yaml や docker-compose を使うプロダクトですか?
   Yes → spirit-room open --docker [folder] で起動
   No  → spirit-room open [folder] で起動
```

- 利点: 明示的で誤判定なし
- 欠点: 質問が 1 つ増える

**案 B (自動判定): 生成した MISSION.md をスキャン**

`spirit-room-manager/skills/MR_POPO.md` の launch フェーズで、生成済み MISSION.md を grep:

```bash
if grep -q -E 'docker compose|docker-compose|compose\.ya?ml|services:' MISSION.md; then
    spirit-room open --docker "$folder"
else
    spirit-room open "$folder"
fi
```

- 利点: ユーザーが意識しなくてよい
- 欠点: キーワードベースなので誤判定 (単に "docker" と書いてあるだけで --docker が付く等) の可能性

**推奨:** 案 A をベースに、MISSION.md 生成テンプレートに「Docker Compose 使用: Yes/No」欄を追加する折衷案。テンプレートに明記することで Claude (修行側) も意図を正確に認識できる。

## 参照

- Phase 6 CONTEXT.md `<deferred>`: 「Mr.ポポが MISSION 内容から --docker を自動判定」
- `spirit-room-manager/skills/MR_POPO.md` — 現行 hiring workflow
- `.planning/phases/06-spirit-room-docker-docker-compose/` — Phase 6 の全アーティファクト
