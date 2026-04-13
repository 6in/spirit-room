# Requirements: 精神と時の部屋

**Defined:** 2026-04-13
**Core Value:** Mr.ポポにフレームワーク名と目的を伝えたら、Claude Codeが自律的にPOCを実装して動くところまで完成させる

## v1 Requirements

### Build

- [ ] **BUILD-01**: `./build-base.sh` がエラーなく完了し、`spirit-room-base:latest` イメージが生成される
- [ ] **BUILD-02**: Dockerfile の全依存パッケージ（Node.js 20、Bun、Claude Code CLI、SSH、Redis、SQLite）が正常インストールされる

### Runtime

- [ ] **RUN-01**: `spirit-room open [folder]` でコンテナが起動し、SSH接続できる
- [ ] **RUN-02**: コンテナ内でRedisが自動起動する
- [ ] **RUN-03**: tmux 3ペイン（training / logs / workspace）が正常に立ち上がる
- [ ] **RUN-04**: `spirit-room enter [folder]` でtmuxセッションにアタッチできる

### Auth

- [ ] **AUTH-01**: コンテナ内でClaude Code認証が完了できる（`spirit-room auth` 経由）
- [ ] **AUTH-02**: 認証ボリューム（`spirit-room-auth`）が複数の部屋をまたいで共有される

### Training Loop

- [ ] **LOOP-01**: `start-training.sh` がPHASE1を実行し、依存パッケージをインストールして `.prepared` フラグを作成する
- [ ] **LOOP-02**: `start-training.sh` がPHASE2を実行し、MISSION.mdの実装完了後に `.done` フラグを作成する
- [ ] **LOOP-03**: コンテナ再起動後に `.prepared`/`.done` フラグを検出してフェーズをスキップし、正しいフェーズからレジュームする
- [ ] **LOOP-04**: `claude -p` のフラグ構文が現行バージョンで正常動作する

### End-to-End

- [ ] **E2E-01**: `spirit-room-manager` でMr.ポポを起動し、ヒアリング → MISSION.md生成まで完了する
- [ ] **E2E-02**: 生成されたMISSION.mdを使って `spirit-room open` → 修行ループが起動する
- [ ] **E2E-03**: Claude Codeがサンプルフレームワーク（LangGraph等）のPOCを実装し `.done` を作成する

## v2 Requirements

### Monitoring

- **MON-01**: `spirit-room monitor start` でWebサーバーが起動する
- **MON-02**: ブラウザからリアルタイムのトレーニングログを確認できる（SSE）
- **MON-03**: `spirit-room monitor open` でブラウザが自動で開く

### CLI Enhancement

- **CLI-01**: ポートがフォルダ名ハッシュから決定論的に計算される（再起動後に同じポートを使用）
- **CLI-02**: `spirit-room list` でポート・経過時間・フェーズ状態を表示する

### opencode

- **OC-01**: opencode のインストールパッケージ名が確認・修正される
- **OC-02**: `start-training.sh opencode` でopencodeエンジンを使った修行が完了する

## Out of Scope

| Feature | Reason |
|---------|--------|
| モニタリングWeb UI | コア動作優先。Bun + SSE + docker.sock は別フェーズ |
| opencode サポート検証 | まずClaudeで動かすことを優先 |
| ポートの決定論的計算 | 現在のauto-port選択で運用に支障なし |
| docker-compose.yml 自動生成 | Mr.ポポが手動判断で生成する設計のまま |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | Phase 1 | Pending |
| BUILD-02 | Phase 1 | Pending |
| RUN-01 | Phase 1 | Pending |
| RUN-02 | Phase 1 | Pending |
| RUN-03 | Phase 1 | Pending |
| RUN-04 | Phase 1 | Pending |
| AUTH-01 | Phase 2 | Pending |
| AUTH-02 | Phase 2 | Pending |
| LOOP-01 | Phase 2 | Pending |
| LOOP-02 | Phase 2 | Pending |
| LOOP-03 | Phase 2 | Pending |
| LOOP-04 | Phase 2 | Pending |
| E2E-01 | Phase 3 | Pending |
| E2E-02 | Phase 3 | Pending |
| E2E-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-13*
*Last updated: 2026-04-13 after initial definition*
