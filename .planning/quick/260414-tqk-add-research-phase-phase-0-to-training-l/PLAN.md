---
quick_id: 260414-tqk
type: quick
created: 2026-04-14
---

# Quick Task: PHASE 0 (RESEARCH) を training loop に追加

## 目的

修行ループの最初に「調査フェーズ」を追加し、AI がフレームワークを触る前に利用パターン・API 基礎・落とし穴を調べて `RESEARCH.md` にまとめるようにする。以降の PREPARE / TRAINING が RESEARCH.md を参照することで実装の迷子を減らし、ブログ用途としても「人間が読む一次レポート」が自動生成される。

## 変更ファイル

1. `spirit-room/base/scripts/start-training.sh`
   - PHASE 0 (RESEARCH) ブロックを PHASE 1 (PREPARE) の前に追加
   - フラグ: `/workspace/.researched`
   - AI への指示: 公式ドキュメント・サンプルコードを調査し `RESEARCH.md` を作成。**コードもインストールもしない**

2. `spirit-room/base/scripts/MISSION.md.template`
   - 成果物セクションに `RESEARCH.md` を追記
   - 「AI の調査結果」として人間の読み物になることを記載

3. `spirit-room-manager/skills/MR_POPO.md`
   - MISSION.md 生成ルールに「RESEARCH フェーズで何を調べさせたいか」の観点を追加
   - 完了条件に `RESEARCH.md` の存在チェックを入れる

4. `spirit-room/build-base.sh` 実行（イメージ再ビルド）

5. STATE.md の quick tasks テーブル更新

## 完了条件

- [ ] `start-training.sh` に PHASE 0 ブロックが存在し、`.researched` フラグで制御される
- [ ] PHASE 1 (PREPARE) のプロンプトが `RESEARCH.md` を参照するよう更新されている
- [ ] PHASE 2 (TRAINING) のプロンプトも `RESEARCH.md` を参照
- [ ] MISSION.md.template に RESEARCH.md の存在が明記されている
- [ ] MR_POPO.md のヒアリング手順が RESEARCH 観点を含む
- [ ] `spirit-room-base:latest` が新 `start-training.sh` を含んで再ビルド済み
- [ ] Docker イメージ内で `grep 'PHASE 0' /room/scripts/start-training.sh` が hit する

## 非破壊性

既存の `.prepared` / `.done` フラグロジックは維持。`.researched` は新規追加のみ。既存部屋（既に `.prepared` がある）の挙動は変わらない（`.researched` がなければ PHASE 0 が走るが、PREPARE がスキップされる）。

→ **注意:** 既存の `.prepared` がある古い部屋では PHASE 0 が新規実行される。これは許容（一度きりの副作用）。
