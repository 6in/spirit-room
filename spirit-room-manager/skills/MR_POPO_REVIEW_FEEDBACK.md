# MR. POPO - feedback レビュースキル (明示起動のみ)

> D-07: このスキルは **人間が明示的にトリガしたときだけ** 読む。Mr.ポポ起動時に自動で読むことは禁止。
> このスキルが存在するのは、部屋の REPORT.md から抽出された feedback を Mr.ポポと対話しながら MISSION.md テンプレートに反映するため。

---

## トリガ

ユーザーが以下のいずれかを言ったら、このスキルを起動する:

- "feedback レビューして"
- "MISSION テンプレ更新したい"
- "溜まった feedback 見せて"
- "mr-popo-review-feedback"
- 類似の明示的リクエスト

それ以外の通常のヒアリング導線では、このスキルを自動で読み込まない。

---

## 責務

1. `.planning/mr-popo-memory/` に溜まった pending feedback を集計
2. mission_type 別に整理して提示
3. 1 件ずつユーザーにレビューさせ、採用する差分を決める
4. 採用された差分を `spirit-room/base/scripts/MISSION.md.template` に反映
5. 処理済み feedback を `applied/` に移動し、ヘッダの Review status を `pending → applied` に更新
6. 変更をコミット (ユーザー確認のうえ)

---

## リポジトリ前提 (Step R5 で使う)

このスキルは `spirit-room-manager/` (spirit-room-full リポジトリ内) で起動される。spirit-room-manager と spirit-room は **同一 git リポジトリの兄弟ディレクトリ** なので、commit 時のリポルートは実行時に解決する:

```bash
# リポルート自動解決 (ハードコードのパスは使わない)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    echo "[ERROR] spirit-room-full リポジトリ内で実行すること" >&2
    exit 1
fi
```

MISSION.md.template のパスは常に `$REPO_ROOT/spirit-room/base/scripts/MISSION.md.template`。Mr.ポポの Edit ツール呼び出し時もこのパスを組み立てて使う。

代替として、spirit-room-manager から見た **相対パス `../spirit-room/base/scripts/MISSION.md.template`** も兄弟配置前提で常に成立する。どちらで解決しても良いが、ハードコード絶対パス (例: 任意プロジェクトルートの絶対パス) は使わない。

---

## 対話フロー (6 ステップ)

**全てのユーザー向け問いかけは `AskUserQuestion` ツールで行え。** フリーテキストの質問を並べるな。

### Step R1: 対象プロジェクト確定

ユーザーがどのプロジェクトの feedback をレビューしたいか確定する。カレントディレクトリに `.planning/mr-popo-memory/` があればそれをデフォルト候補にする。

1. `bash` で `find "$HOME/projects" -maxdepth 3 -type d -name "mr-popo-memory" 2>/dev/null` を実行し、候補を列挙
2. `AskUserQuestion` で「どのプロジェクトの feedback をレビューする?」と聞く。選択肢は上で見つかったパス (最大 5 件) + "パスを手入力" + "現在のディレクトリ" の混合

```
AskUserQuestion(
  question: "どのプロジェクトの feedback をレビューする?",
  header: "レビュー対象",
  multiSelect: false,
  options: [
    { label: "~/projects/langgraph-poc/.planning/mr-popo-memory/", description: "見つかった候補 1" },
    { label: "~/projects/other-project/.planning/mr-popo-memory/", description: "見つかった候補 2" },
    { label: "現在のディレクトリ",     description: "$(pwd)/.planning/mr-popo-memory/" },
    { label: "パスを手入力 (自由記述)", description: "上記にないパスを直接指定" }
  ]
)
```

確定したパスを `$MEMORY_DIR` とする。

### Step R2: pending feedback の集計

`$MEMORY_DIR` 配下を mission_type 別にスキャンする。applied/ サブディレクトリは除外する。

```bash
for type_dir in "$MEMORY_DIR"/*/; do
    type_name=$(basename "$type_dir")
    [ "$type_name" = "applied" ] && continue
    count=$(find "$type_dir" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l)
    echo "${type_name}: ${count} 件"
done
```

結果をユーザーに提示 (普通の echo で可。選択肢に多すぎる type がある場合のみ AskUserQuestion にする)。

### Step R3: レビューする mission_type を選ばせる

`AskUserQuestion` で 1 つ選ばせる。0 件の type は選択肢から除外する。

```
AskUserQuestion(
  question: "どの mission_type の feedback からレビューする?",
  header: "mission_type 選択",
  multiSelect: false,
  options: [
    { label: "poc (3件)",         description: "POC 系の feedback 3件" },
    { label: "refactoring (2件)", description: "リファクタ系 2件" },
    { label: "すべてまとめて",      description: "mission_type をまたいで順に見る" },
    { label: "終了",              description: "今日は見ないで終わる" }
  ]
)
```

### Step R4: 1 件ずつ feedback を提示してレビュー

選んだ mission_type のディレクトリ内のファイルを 1 件ずつ開き、内容を表示してからレビューを聞く。

```bash
for f in "$MEMORY_DIR/$selected_type/"*.md; do
    [ ! -f "$f" ] && continue
    cat "$f"   # ユーザーに中身を見せる
    # この後 AskUserQuestion で処理を選ばせる
done
```

各ファイルに対して `AskUserQuestion`:

```
AskUserQuestion(
  question: "この feedback をどう扱う?",
  header: "feedback 処理",
  multiSelect: false,
  options: [
    {
      label: "採用 (diff をテンプレに反映)",
      description: "suggested_template_diff を MISSION.md.template に適用 → applied/ に移動"
    },
    {
      label: "部分採用 (編集してから反映)",
      description: "diff を人間が編集してから反映 → applied/ に移動"
    },
    {
      label: "却下 (採用しない)",
      description: "反映せずに applied/ に移動 (レビュー済みとして除外)"
    },
    {
      label: "保留 (次回に回す)",
      description: "何もせず次の feedback へ (Review status は pending のまま)"
    },
    {
      label: "このセッションを終える",
      description: "残りは次回レビュー"
    }
  ]
)
```

### Step R5: 採用された diff をテンプレに反映

「採用」または「部分採用」が選ばれた場合のみ:

1. feedback ファイルの `suggested_template_diff` ブロックを取り出す (yq または awk で)
2. 「部分採用」の場合はユーザーに編集版を `AskUserQuestion` (自由記述) で入力させる
3. `$REPO_ROOT/spirit-room/base/scripts/MISSION.md.template` の該当箇所を Edit ツールで書き換える
   - 反映対象箇所の特定が曖昧な場合は、**Edit 実行前に必ず具体的な変更内容を提示してユーザーに承認させる** (AskUserQuestion: "この編集内容で反映してよいか? [yes / 編集する / キャンセル]")
   - `$REPO_ROOT` は `git rev-parse --show-toplevel` で解決する (ハードコードパス禁止)
4. 反映後、コミット:
   ```bash
   # リポルートを実行時解決 (ハードコードしない。spirit-room-manager と spirit-room は同居前提)
   REPO_ROOT=$(git rev-parse --show-toplevel)
   if [ -z "$REPO_ROOT" ]; then
       echo "[ERROR] git リポジトリ外で実行されている — commit スキップ" >&2
       # ここで処理終了させずに Step R6 へは進む (ファイル編集自体は成功しているため)
   else
       cd "$REPO_ROOT"
       git add spirit-room/base/scripts/MISSION.md.template
       git commit -m "feat(phase-07): apply feedback from {room-slug} to MISSION.md.template"
   fi
   ```

### Step R6: 処理済み feedback を applied/ に移動

「採用」「部分採用」「却下」のいずれかが選ばれた場合:

1. `$MEMORY_DIR/$selected_type/applied/` ディレクトリを mkdir -p で作成
2. feedback ファイルのヘッダ `- Review status: pending` を `- Review status: applied (YYYY-MM-DD)` に書き換え
   - 却下の場合は `- Review status: rejected (YYYY-MM-DD)`
   - Plan 07-04 で確定した plain key 形式 (太字マーカー `**` なし) を前提に 1 行書き換えで済む。**`YYYY-MM-DD` は必ず `$(date +%F)` で展開すること** (リテラルの `YYYY-MM-DD` をそのまま書き込まないよう注意):
     ```bash
     TODAY=$(date +%F)
     sed -i "s/^- Review status: pending$/- Review status: applied (${TODAY})/" "$feedback_file"
     # 却下時:
     # sed -i "s/^- Review status: pending$/- Review status: rejected (${TODAY})/" "$feedback_file"
     ```
3. `git mv` で `applied/` 配下に移動 (git 履歴を保つため `mv` ではなく `git mv`)
4. コミット:
   ```bash
   # ここもリポルートを実行時解決する (プロジェクトルートがハードコードされないように)
   PROJECT_ROOT=$(cd "$MEMORY_DIR" && git rev-parse --show-toplevel 2>/dev/null)
   if [ -n "$PROJECT_ROOT" ]; then
       cd "$PROJECT_ROOT"
       git add -A
       git commit -m "chore(mr-popo-memory): move reviewed feedback to applied/"
   fi
   ```

---

## ベースイメージ再ビルドの案内

MISSION.md.template を変更した場合、次回の部屋起動でテンプレが反映されるために rebuild が必要。レビューセッション終了時にユーザーに案内する:

> MISSION.md.template を更新した。次回の部屋起動でテンプレを反映するため、ベースイメージを再ビルドせよ:
>   REPO_ROOT=$(git rev-parse --show-toplevel) && cd "$REPO_ROOT" && ./spirit-room/build-base.sh

(rebuild を忘れると古いテンプレで部屋が立つ。必須手順として毎回案内。リポルートも `git rev-parse` で解決する)

---

## 終了時の報告フォーマット

```
feedback レビュー完了 (session summary):

  レビュー済み: 5 件
  採用       : 3 件 (→ MISSION.md.template に反映済)
  部分採用   : 1 件 (→ MISSION.md.template に反映済、diff は編集あり)
  却下       : 1 件
  保留       : 0 件

  変更ファイル: spirit-room/base/scripts/MISSION.md.template
  次回の部屋起動前に ./spirit-room/build-base.sh で rebuild を忘れるな。
```

---

## 禁止事項

- Mr.ポポの通常ヒアリング (`MR_POPO.md` の Step 0〜3 / K1〜K5) を自動で起動しない — このスキルは独立したフロー
- 過去の applied/ フォルダの feedback を再レビュー対象にしない
- MISSION.md.template 以外のテンプレ (KAIO-MISSION.md.template / catalog.md 等) は本 phase ではスコープ外。suggested_template_diff で言及があっても「本 phase では MISSION.md.template のみ」とユーザーに伝える
- ユーザーの明示承認なく Edit / git commit を実行しない
- feedback ファイルを削除しない。必ず applied/ に移動 (履歴を残す)
- **パスをハードコードしない** (任意プロジェクトルートの絶対パスは禁止)。リポルートは常に `git rev-parse --show-toplevel` で解決すること
