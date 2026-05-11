---
phase: 07-mr-popo-feedback-loop
reviewed: 2026-04-23T12:45:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - spirit-room-manager/CLAUDE.md
  - spirit-room-manager/skills/MR_POPO.md
  - spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md
  - spirit-room/base/scripts/KAIO-MISSION.md.template
  - spirit-room/base/scripts/MISSION.md.template
  - spirit-room/base/scripts/create-report.md
  - spirit-room/base/scripts/extract-feedback.sh
  - spirit-room/base/scripts/start-training.sh
findings:
  critical: 0
  warning: 4
  info: 6
  total: 10
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-04-23T12:45:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 7 (Mr.ポポ feedback loop) の 8 ファイルを standard depth でレビューした。Critical 級の致命バグはなし。Warning 4 件はいずれも bash の堅牢性に関するもの (cd 失敗ハンドリング、set -e 非採用に伴うエラーマスク、awk の frontmatter 抽出がファイル先頭以外でも発火する edge case、sed のレンジ演算が非閉鎖時に意図せぬ範囲を拾う件)。いずれも「通常運用では顕在化しにくいが、破損 REPORT.md / 異常なマウント状態で発火すると silent failure を招く」タイプ。Info 6 件はドキュメント改善・変数クォート強化・テンプレ記述の明瞭化。

全体として Phase 07 の設計 (明示トリガ型レビュー、`Review status: pending` plain key、yq ベース抽出、リポルート `git rev-parse` 解決) は筋が通っており、パス注入や TOCTOU 系のセキュリティ欠陥は見当たらなかった。

## Warnings

### WR-01: `cd /workspace` の失敗ハンドリング欠落 (start-training.sh)

**File:** `spirit-room/base/scripts/start-training.sh:85, 109`
**Issue:** `init_git_workspace()` と `phase_commit()` で `cd /workspace` を実行するが、戻り値チェックが無く、また上位で `set -e` も無いため `/workspace` が存在しない・権限が無い場合、カレントディレクトリは直前のまま (= `/` またはスクリプト実行時の CWD) で `git init` / `git add -A` / `git commit` が走る。最悪の場合 `/` 直下や `/room/` に `.git` が作られてコンテナ状態を汚染しうる。
**Fix:**
```bash
init_git_workspace() {
    cd /workspace || { log "[ERROR] /workspace に cd できない — git 初期化中止"; return 1; }
    ...
}

phase_commit() {
    local msg="$1"
    cd /workspace || { log "[WARN] /workspace に cd できない — commit スキップ"; return 0; }
    ...
}
```

### WR-02: `extract-feedback.sh` の `_yq()` で `echo ""` にフォールバックしても `set -u` 下でトリガしない隠れ条件

**File:** `spirit-room/base/scripts/extract-feedback.sh:35-45`
**Issue:** `_yq()` 内で `_val=$(echo "$FRONTMATTER" | yq "$1" 2>/dev/null || echo "")` としているが、`echo "$FRONTMATTER" | yq ...` のパイプは、yq 自体が存在しない (未インストール) 場合にシェル側で `command not found` が stderr に出て `_val` は空になる。そこまでは期待通りだが、yq がバイナリとして存在するが解析エラーを返したとき (破損 YAML、多重 `---` 混入等) に `_val="null"` が入ることがあり、その後の `[ "$_val" = "null" ]` で空文字化される。**問題は yq が複数行 YAML で想定外の出力 (e.g. error to stdout) を返したケース**。yq v4 系 (mikefarah) は通常 stderr にエラーを出すので実害は低いが、yq v3 系 (Python kislyuk 版) が入っていた場合に挙動が変わる。Dockerfile で yq バージョン固定を明示せよ。
**Fix:** コメントで yq バージョン前提 (mikefarah Go 版 v4+) を明記し、CI で `yq --version` 確認を入れる。
```bash
# 冒頭コメント追記:
# 前提: yq は mikefarah 版 Go yq v4+ (Python kislyuk 版は非サポート)
# Dockerfile で固定バージョンをインストールすること
```
さらに防御的に `_yq()` へ型チェックを追加:
```bash
_yq() {
    command -v yq >/dev/null 2>&1 || { echo ""; return; }
    local _val
    _val=$(printf '%s\n' "$FRONTMATTER" | yq -r "$1" 2>/dev/null)
    [ "$_val" = "null" ] || [ -z "$_val" ] && { echo ""; return; }
    echo "$_val"
}
```

### WR-03: awk の frontmatter 抽出が 2 つ目の `---` 欠落時に全文出力する

**File:** `spirit-room/base/scripts/extract-feedback.sh:27`
**Issue:** `awk '/^---$/{c++; if(c==2) exit; next} c==1' "$REPORT_FILE"` は、1 つ目の `---` は正しく検出するが、2 つ目の `---` がファイル内に存在しない場合 (壊れた REPORT.md / frontmatter 閉じ忘れ) に c=1 のまま最終行まで出力し続ける。結果として `$FRONTMATTER` 変数に本文 Markdown が全て詰め込まれ、yq が「YAML っぽい箇所だけ拾って成功した風」のゴミを返す可能性がある。
**Fix:** awk の後に「閉じ `---` が見つかったか」のガードを追加:
```bash
FRONTMATTER=$(awk '
  /^---$/ { c++; if (c==1) { found_open=1; next } if (c==2) { found_close=1; exit } next }
  c==1
' "$REPORT_FILE")

# 閉じ `---` が無かった場合は不正 frontmatter とみなす
CLOSE_COUNT=$(grep -c '^---$' "$REPORT_FILE")
if [ "$CLOSE_COUNT" -lt 2 ]; then
    log "[WARN] REPORT.md の frontmatter が閉じていない (--- が ${CLOSE_COUNT} 回のみ) — 抽出スキップ"
    exit 0
fi
```

### WR-04: start-training.sh の `sed -n '/^---$/,/^---$/p'` がフロントマター閉じ忘れで全文拾う

**File:** `spirit-room/base/scripts/start-training.sh:47`
**Issue:** `resolve_max_iterations()` 内で MISSION.md の frontmatter 抽出に `sed -n '/^---$/,/^---$/p'` を使っているが、sed のレンジ `a,b` は b にマッチしないまま EOF に達するとファイル末尾まで出力する。MISSION.md が frontmatter 閉じ `---` を忘れている場合、本文中の `max_iterations:` っぽい文字列 (ユーザー自由記述部分に偶然書かれた) を拾ってしまう可能性がある。grep で `^max_iterations:` を絞っているので実害は低いが、ユーザーが本文に `max_iterations: 999` と冗談で書いた場合に拾われる。
**Fix:** awk で閉じマッチを強制するか、`head -n 20` で frontmatter 候補範囲を絞る:
```bash
# awk 版 (閉じ --- が必須)
_fm_val=$(awk '
  /^---$/ { c++; if (c==1) next; if (c==2) exit }
  c==1 && /^max_iterations:[[:space:]]*[0-9]+/ { print; exit }
' "$MISSION_FILE" | awk -F: '{gsub(/[[:space:]]/, "", $2); print $2}')
```

## Info

### IN-01: `_yq()` 内 `echo` の空文字判定が冗長

**File:** `spirit-room/base/scripts/extract-feedback.sh:39-44`
**Issue:** `_val=$(... || echo "")` で既に空にフォールバックしているので、直後の `if [ "$_val" = "null" ]; then echo ""; else echo "$_val"; fi` は `[ "$_val" = "null" ] && _val=""` の 1 行で済む。
**Fix:**
```bash
_yq() {
    local _val
    _val=$(printf '%s\n' "$FRONTMATTER" | yq "$1" 2>/dev/null)
    [ "$_val" = "null" ] && _val=""
    printf '%s\n' "$_val"
}
```
加えて `echo "$FRONTMATTER"` は先頭の `-e` / `-n` 等で誤動作するリスクがあるので `printf '%s\n'` 推奨。

### IN-02: `MR_POPO_REVIEW_FEEDBACK.md` の `$HOME/projects` がクォートされていない例示

**File:** `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md:60`
**Issue:** `find $HOME/projects -maxdepth 3 ...` がクォート無し。`$HOME` にスペースが含まれる環境 (Mac の一部ユーザー名) でパス展開が壊れる。実運用ではレアだがドキュメント例としての悪い先例。
**Fix:**
```bash
find "$HOME/projects" -maxdepth 3 -type d -name "mr-popo-memory" 2>/dev/null
```

### IN-03: Step R6 の `sed` 書き換えで日付リテラルが未展開のまま例示されている

**File:** `spirit-room-manager/skills/MR_POPO_REVIEW_FEEDBACK.md:186`
**Issue:** `sed 's/^- Review status: pending/- Review status: applied (YYYY-MM-DD)/'` の `YYYY-MM-DD` はリテラルで書かれており、実装時に `$(date +%F)` で置き換えるのかが曖昧。Mr.ポポが素直に `YYYY-MM-DD` という文字列をファイルに書き込むリスクがある。
**Fix:** 実装時の sed を明示:
```bash
TODAY=$(date +%F)
sed -i "s/^- Review status: pending$/- Review status: applied (${TODAY})/" "$feedback_file"
```

### IN-04: `spirit-room-manager/CLAUDE.md` の起動コマンド表が `spirit-room-manager` 側の実際のコマンドと重複

**File:** `spirit-room-manager/CLAUDE.md:17-26`
**Issue:** `MR_POPO.md` 側にも類似のコマンド一覧があり、二重管理になっている。将来片方だけ更新されて drift する典型パターン。どちらかを source of truth にして他方は参照すべき。Phase 07 で直接壊れる訳ではないので Info。
**Fix:** `CLAUDE.md` 側は「詳細は `skills/MR_POPO.md` を参照」に簡素化するか、逆にスキル側を簡素化する。今回は追加しなくてよいが将来の技術的負債として記録。

### IN-05: MISSION.md.template / KAIO-MISSION.md.template の YAML frontmatter 末尾コメント

**File:** `spirit-room/base/scripts/MISSION.md.template:1-5`, `spirit-room/base/scripts/KAIO-MISSION.md.template:1-5`
**Issue:** frontmatter 内に `# poc / refactoring / testdata / investigation — Mr.ポポが Step 0.5 で確定する` のような行末コメントがある。YAML 的には合法だが、ユーザーが MISSION.md を生成する際にコメントごとコピーしてしまい `mission_type: poc           # poc / ...` のような行が残るとスカラー値は `poc` で OK だが、将来 yq のパースでコメント剥離挙動が変わると事故る可能性。軽微。
**Fix:** コメントを frontmatter 外の本文側に移すとより堅牢:
```yaml
---
mission_type: poc
max_iterations: 50
feedback_schema_version: 1
---

<!-- mission_type: poc / refactoring / testdata / investigation
     Mr.ポポが Step 0.5 で確定する -->
```

### IN-06: `extract-feedback.sh` の `echo "$FRONTMATTER"` で `-e` 始まりを拾うリスク

**File:** `spirit-room/base/scripts/extract-feedback.sh:39, 101`
**Issue:** `echo "$FRONTMATTER" | yq ...` と `echo "$FRONTMATTER"` を `{ ... } > "$TARGET_FILE"` に挿入しているが、FRONTMATTER の先頭行が `-e foo:` のような YAML (ありえないが防御的に) だと bash の `echo` が `-e` をフラグとして解釈し欠落する。`printf` 使用推奨。
**Fix:**
```bash
# _yq 内
_val=$(printf '%s\n' "$FRONTMATTER" | yq "$1" 2>/dev/null || echo "")

# 保存ファイル生成 (101 行目付近)
printf '%s\n' "$FRONTMATTER"
```

---

_Reviewed: 2026-04-23T12:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
