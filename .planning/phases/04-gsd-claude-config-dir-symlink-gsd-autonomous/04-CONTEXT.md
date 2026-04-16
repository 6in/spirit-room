# Phase 4: 界王星モード — Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Direct capture from design conversation (POC-validated)

<domain>
## Phase Boundary

精神と時の部屋プロジェクトに **界王星モード** を追加する。これは既存の「精神と時の部屋」(POC速攻型の2フェーズループ)とは別モードで、Docker部屋の中で GSD ワークフローを使った**本格的な段階開発**をエージェントに回させる。

世界観の対比:
- **精神と時の部屋** (既存): 時間を圧縮して素振り量を稼ぐ → POC速攻
- **界王星** (新規): 重力10倍で基礎を鍛える → フェーズ分割・要件・検証ありの本格開発

Phase 4 の成果物は、ホスト側の新しい `kaio` サブコマンド、部屋内の新しい training スクリプト、および Mr.ポポのモード分岐。Phase 3 で完成した E2E フロー (Mr.ポポ → MISSION.md → 部屋起動 → POC完成) の上に、もう一つの起動経路を並行して追加する。

</domain>

<decisions>
## Implementation Decisions

### アーキテクチャの基本方針

- **既存の精神と時の部屋ループは壊さない**: 現状の `spirit-room open` / `start-training.sh` / 2フェーズループはそのまま残す。界王星モードは追加経路。
- **モード分岐点は Mr.ポポ**: ユーザーとのヒアリング最初の1問目で「精神と時の部屋 (POC速攻) / 界王星 (本格開発)」を選ばせ、以降の質問と生成物 (MISSION.md or KAIO-MISSION.md) をモード別に分岐する。
- **実行経路も分岐**: `spirit-room open` は精神と時の部屋専用のまま、`spirit-room kaio [folder]` を新規追加して界王星モードの部屋を起動する。共通ロジックはヘルパー関数に切り出す。
- **部屋内の training 経路も分岐**: `start-training.sh` は既存のまま。`start-training-kaio.sh` を新規追加して GSD 駆動のチェーンを実装する。

### CLAUDE_CONFIG_DIR による GSD 隔離

POC で検証済 (`/tmp/kaio-poc` で完走確認):

- 各部屋は `CLAUDE_CONFIG_DIR=/workspace/.claude-home` を指定して起動する
- その結果、GSDスキル・設定・プロジェクト状態 (`.claude.json` 等) が部屋ローカルに隔離される
- GSD のインストールは `npx get-shit-done-cc@latest` を `CLAUDE_CONFIG_DIR` 環境下で実行することで、そのディレクトリに 73 skills + `get-shit-done/` 本体 + hooks + settings.json が配置される (POC実測)
- ホスト側の `~/.claude/` は一切汚染されない / 既存の精神と時の部屋セッションとも干渉しない

### 認証の引き継ぎ戦略

POC で課題として確認済 → **symlink 方式** で解決:

- `CLAUDE_CONFIG_DIR` を切り替えた瞬間、既存の認証共有 volume 戦略 (`spirit-room-auth` に `/root/.claude` 全体をマウント) と矛盾する
- 解決策: 部屋の entrypoint が、共有 volume 内の認証ファイル (`.credentials.json`, `.claude.json` 等) を `CLAUDE_CONFIG_DIR` 配下に **symlink** で配置する
- symlink にすることで、Claude Code がトークンをリフレッシュしたとき共有 volume 側に反映され、他の部屋にも伝播する。コピー方式だと各部屋が孤立して再認証地獄になる。
- 認証対象ファイルは最低限 `.credentials.json`。POC では `.credentials.json` の symlink だけで `claude -p` 経由の認証が通った。
- `~/.claude.json` (プロジェクト履歴 + MCP設定 等) の扱いは要検証: 部屋ローカルで良いのか、共有したいのか。**デフォルトは symlink しない** (部屋ローカル) で開始し、必要なら後で追加する。

### training-kaio の非対話駆動

POC で検証済 (`/gsd-new-project` → `/gsd-autonomous` 完走 / 13コミット / `v1.0` タグ生成):

- `start-training-kaio.sh` は `claude -p "<プロンプト>" --permission-mode bypassPermissions` を1回呼ぶだけ
- プロンプトは以下を含む:
  1. `KAIO-MISSION.md` を読むよう指示
  2. `/gsd-new-project` を実行し、MISSION 内容を事前回答として使うよう指示
  3. 続けて `/gsd-autonomous` を実行するよう指示
  4. **非対話モード宣言**: 「人間はいない、AskUserQuestion は禁止、質問の代わりに推奨デフォルトを選んで進行」という明示指示
- 完了条件は既存ループと同じく `/workspace/.done` フラグで判定。GSD が `v1.0` タグを作った段階で `.done` を書き出すラッパー処理が必要。
- 再開性: 途中停止に備えて、GSD の `.planning/state.json` を見て resume できるようラッパーを組む。最小版では「最初から全部やり直し」で妥協可 (`.planning/` が既存なら `/gsd-resume-work` に切り替える程度)。

### KAIO-MISSION.md テンプレート

既存の `MISSION.md.template` (POC向け) とは別物として `KAIO-MISSION.md.template` を用意:

- 既存項目 (目的 / 完了条件 / 技術スタック / 制約) は踏襲
- 追加項目:
  - **要件の粒度ヒント**: GSD が要件分解するので、ユーザーは大まかな機能リストだけで良い
  - **フェーズ分割の示唆**: 「どう段階的に作りたいか」のヒント (任意)
  - **成功条件の具体性**: GSD は verify 段階で success criteria をチェックするので、テスト可能な形で書く必要がある
- Mr.ポポは界王星モード選択時にこのテンプレートを元にヒアリングする

### Mr.ポポのヒアリング分岐

- 現状の `spirit-room-manager/skills/MR_POPO.md` は3問ヒアリング (framework / goal / constraints) のみ
- Phase 4 では1問目に「モード選択」を追加:
  - 精神と時の部屋: フレームワークを触って動くPOCが欲しい → 既存の3問ヒアリング → `MISSION.md` → `spirit-room open`
  - 界王星: 複数フェーズに分けて段階的に本格実装したい → KAIO向け追加ヒアリング → `KAIO-MISSION.md` → `spirit-room kaio`
- 界王星の追加ヒアリング項目は KAIO-MISSION.md テンプレートに対応する3〜5問程度

### 成功条件 (Phase 4 としての)

1. `spirit-room kaio [folder]` が新しいコンテナを起動し、`CLAUDE_CONFIG_DIR=/workspace/.claude-home` が設定されている
2. 部屋の entrypoint が `.credentials.json` を共有 volume から symlink し、部屋内で `claude -p "hello"` が認証エラーなく通る
3. 部屋の初回起動時に GSD が `CLAUDE_CONFIG_DIR` 配下にインストールされる (既にインストール済なら skip)
4. `start-training-kaio.sh` が `KAIO-MISSION.md` を読み、`/gsd-new-project` → `/gsd-autonomous` を非対話で走らせ、`.done` フラグを作る
5. Mr.ポポが界王星モードを選べる (最初の1問分岐)
6. E2E: Mr.ポポで界王星モードを選んで KAIO-MISSION.md を生成 → `spirit-room kaio` で起動 → 界王星ループが完走 → `.planning/` に成果物ができている

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 既存の精神と時の部屋ループ (手を入れずに参考にすべき)
- `spirit-room/spirit-room` — 現状のホストCLI。`cmd_open()`, `find_free_port()`, 共有 volume マウント処理。界王星の `cmd_kaio()` はこれをほぼ流用する。
- `spirit-room/base/entrypoint.sh` — 現状の部屋 entrypoint。`CLAUDE_CONFIG_DIR` 分岐と symlink 処理を追加する対象。
- `spirit-room/base/scripts/start-training.sh` — 2フェーズループの実装。`start-training-kaio.sh` はこれとは別ファイル。
- `spirit-room/base/scripts/MISSION.md.template` — `KAIO-MISSION.md.template` の雛形。

### Mr.ポポ
- `spirit-room-manager/CLAUDE.md` — Mr.ポポの人格指示。モード分岐の前提。
- `spirit-room-manager/skills/MR_POPO.md` — 3問ヒアリングのワークフロー。1問目にモード選択を追加する対象。
- `spirit-room-manager/HANDOVER.md` — 実装ステータスと設計判断ログ。Phase 4 完了時に追記する。

### プロジェクト憲法
- `CLAUDE.md` — 応答言語 (日本語) / Tech Stack制約 (bash + Docker のみ — Node.js/Python追加禁止) / Dragon Ball世界観の命名 / ブランチ戦略。
- `.planning/PROJECT.md` — コアバリュー「Mr.ポポに伝えたら Claude Code が自律的にPOCを完成させる」。界王星モードはこれを拡張するもので、コアバリューを壊してはいけない。

### POC 検証成果 (設計の裏付け)
- `/tmp/kaio-poc/config/` — GSD が隔離インストールされた `CLAUDE_CONFIG_DIR` の実例
- `/tmp/kaio-poc/project/` — `/gsd-new-project` → `/gsd-autonomous` が完走した実例 (13 commits, `v1.0` tag, `today.sh` + tests)

</canonical_refs>

<specifics>
## Specific Ideas

### POC で確認した具体コマンド

GSD インストール (部屋内 or 初回ホストから):
```bash
CLAUDE_CONFIG_DIR=/workspace/.claude-home npx -y get-shit-done-cc@latest
```

非対話で `/gsd-new-project` → `/gsd-autonomous` を連続実行 (プロンプト原型):
```bash
CLAUDE_CONFIG_DIR=/workspace/.claude-home claude -p "Context: This is a POC verifying whether GSD workflows can run end-to-end without human input, from inside an automated training environment. You are running via 'claude -p' so there is NO human available to answer AskUserQuestion prompts — any question you ask will just block.

Task: Read /workspace/KAIO-MISSION.md. Run /gsd-new-project using the mission content as answers. Then run /gsd-autonomous to completion.

Rules:
- Never ask the user anything. For any question the skill would normally ask, pick the recommended/default answer and keep going.
- Prefer the simplest, shortest path to a completed phase.
- If a step genuinely cannot proceed without input, make the most reasonable assumption, log it in a comment, and continue." --permission-mode bypassPermissions
```

認証 symlink (entrypoint 内):
```bash
mkdir -p "$CLAUDE_CONFIG_DIR"
ln -sf /root/.claude-shared/.credentials.json "$CLAUDE_CONFIG_DIR/.credentials.json"
```
(共有 volume のマウント先を `/root/.claude-shared` に移す必要あり — 現状は `/root/.claude` を直接マウントしているので競合する)

### ディレクトリ構成の提案

```
spirit-room/base/scripts/
├── start-training.sh            # 既存 (精神と時の部屋)
├── start-training-kaio.sh       # 新規 (界王星)
├── MISSION.md.template          # 既存
└── KAIO-MISSION.md.template     # 新規
```

### 部屋内での `CLAUDE_CONFIG_DIR` パス選択

- 候補1: `/workspace/.claude-home` — プロジェクト直下。永続化される (再起動しても残る)。
- 候補2: `/root/.claude-kaio` — ホームディレクトリ系。コンテナ停止で消える。
- **推奨: 候補1**。部屋を閉じて再度開いたときに GSD の状態 (`.planning/` や インストール済スキル) を継承したい。

</specifics>

<deferred>
## Deferred Ideas

以下は Phase 4 スコープ外。必要になったら別フェーズ or バックログへ:

- **POC → 界王星への昇格フロー**: 精神と時の部屋で作ったものを界王星に持ち込んで本格化する変換機能。将来的に有用だが今回は範囲外。
- **複数界王星の並列実行**: 現状の精神と時の部屋と同様、1部屋1目的で開始。並列実行は後回し。
- **界王星専用の監視UI**: 本格開発は時間が長いので進捗ダッシュボードがあると嬉しいが、Phase 4 はログ tail で妥協。
- **GSD バージョン固定**: `npx get-shit-done-cc@latest` は毎回最新取得。バージョン固定戦略は後で検討。
- **opencode での界王星モード対応**: まずは Claude Code 専用。opencode 分岐は後回し。
- **`~/.claude.json` (プロジェクト履歴) の共有戦略**: Phase 4 は部屋ローカルで開始。必要性が見えたら検討。
- **`.done` 後の成果物回収フロー**: 現状の精神と時の部屋と同じく `/workspace` マウント経由で自動的にホストから見えるので、特別な処理は不要。

</deferred>

---

*Phase: 04-gsd-claude-config-dir-symlink-gsd-autonomous*
*Context gathered: 2026-04-15 — captured directly from design conversation after POC validation*
