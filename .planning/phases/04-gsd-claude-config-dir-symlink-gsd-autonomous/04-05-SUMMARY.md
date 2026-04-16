---
phase: 04-gsd-claude-config-dir-symlink-gsd-autonomous
plan: 05
type: summary
---

# 04-05 SUMMARY: E2E検証 + バグ修正

## 概要

Phase 4 全体を貫通するE2E検証を実施。Mr.ポポで界王星モード選択 → KAIO-MISSION.md生成 → `spirit-room kaio` → GSD非対話チェーン完走 → REPORT.md生成 → 成果物動作確認まで1本のシナリオで確認した。

## E2E検証で発見・修正したバグ

| # | 問題 | 原因 | 修正 |
|---|------|------|------|
| 1 | Mr.ポポが Step 0 モード選択をスキップ | `spirit-room-manager/CLAUDE.md`が「Step 1に進む」のまま | CLAUDE.md にStep 0をインライン記載 |
| 2 | GSDインストーラが対話プロンプトで停止 | `npx -y` はnpx確認のみ、installer本体の質問には効かない | `yes '' \|` でパイプ |
| 3 | `claude -p --bypassPermissions` がrootで拒否 | Claude Code安全チェック | `IS_SANDBOX=1` 環境変数 |
| 4 | 401認証エラー | GSD生成の.claude.jsonに`oauthAccount`がない | ホスト`~/.claude.json`からoauthAccountをjqマージ |
| 5 | OAuthトークン失効 | 共有ボリュームの.credentials.jsonが古い | `cmd_kaio`で毎回ホストから最新を同期 |
| 6 | `spirit-room enter` がkaioコンテナを見つけられない | `folder_to_name`が`-kaio`サフィックスを知らない | `resolve_running_name()`ヘルパー追加 |
| 7 | Dockerfileに`start-training-kaio`のsymlinkがない | 04-01〜04-04では未考慮 | `/usr/local/bin/start-training-kaio` symlink追加 |
| 8 | `spirit-room kaio`が起動のみでenter不要 | 2段階操作は不便 | `cmd_kaio`末尾で`cmd_enter`自動呼び出し |
| 9 | 振り返りレポート(REPORT.md)がない | kaioモードにREPORT相当がなかった | PHASE KAIO-3追加 + `/create-report`スキル |
| 10 | K1に自由記述入力がない | AskUserQuestion化で「何を作りたいか」が消えた | K1-b自由記述質問を追加 |

## 改善 (E2Eフィードバック)

- Mr.ポポの全ヒアリング(Step 0-3, K1-K5)を`AskUserQuestion` UIに統一
- `cmd_kaio`が再実行時に既存コンテナへ直接入室
- Mr.ポポ報告テンプレートで`spirit-room kaio`を入室コマンドに
- `cmd_close`もkaioコンテナ名を自動解決
- `~/.local/bin/spirit-room`をsymlinkに更新

## 成果物

- E2E完走: `~/projects/kaio-svelte-todo-2/.kaio-done` ✅
- GSD成果物: `.planning/` (ROADMAP, REQUIREMENTS, phases) ✅
- REPORT.md生成: `/create-report`スキル経由 ✅
- ビルド・テスト: `npx vite build` pass, 10/10 vitest pass ✅
- git tag v1.0 ✅

## コミット

- `1472fa2` feat(04-05): symlink start-training-kaio into /usr/local/bin
- `edfdb5e` fix(04-05): inline 界王星 mode selection in Mr.ポポ CLAUDE.md
- `b95c9db` fix(04-05): use AskUserQuestion UI for mode selection in Step 0
- `032f167` fix(04-05): wrap all Mr.ポポ hearing steps in AskUserQuestion UI
- `c756dff` fix(04-05): make enter/close auto-detect -kaio containers
- `91e7f80` fix(04-05): auto-sync credentials + oauthAccount merge + auto-enter
- `f885351` feat(04-05): add PHASE KAIO-3 report generation after GSD chain
- `83a789f` feat(04-05): add /create-report skill for 界王星 retrospective
- `9801547` fix(04-05): add free-text input for K1 project description and K2 features
- `34eaf54` fix(04-05): kaio auto-enters on re-run + report template uses kaio
