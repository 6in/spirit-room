---
phase: quick-260421-uiu
plan: 01
subsystem: work/refactoring-java (リファクタリング修行部屋サンプル素材)
tags:
  - quick
  - refactoring
  - java
  - gradle
  - sample-material
dependency_graph:
  requires: []
  provides:
    - work/refactoring-java (アンチパターン 10 ファイル付き Gradle プロジェクト)
  affects:
    - .gitignore (work/refactoring-java/ のみ例外として追跡許可)
tech_stack:
  added:
    - Java 17 (Temurin, javac 17.0.13 で疎通確認)
    - Gradle java + application plugins (骨格のみ記載、host に gradle 未導入のため javac で検証)
    - org.xerial:sqlite-jdbc:3.45.1.0 (build.gradle 宣言のみ、実行時依存)
  patterns:
    - "意図的アンチパターン: 資格情報ハードコード / 生 SQL 文字列連結 / static 可変状態 / 例外握り潰し / リソースリーク / God method"
    - "educational bad example スタイル: コード本体にメタ注釈無し、解説は README.md に集約"
key_files:
  created:
    - work/refactoring-java/settings.gradle
    - work/refactoring-java/build.gradle
    - work/refactoring-java/.gitignore
    - work/refactoring-java/README.md
    - work/refactoring-java/src/main/java/antipatterns/Main.java
    - work/refactoring-java/src/main/java/antipatterns/DatabaseConnection.java
    - work/refactoring-java/src/main/java/antipatterns/LegacyFileReader.java
    - work/refactoring-java/src/main/java/antipatterns/CsvParser.java
    - work/refactoring-java/src/main/java/antipatterns/LogWriter.java
    - work/refactoring-java/src/main/java/antipatterns/ConfigLoader.java
    - work/refactoring-java/src/main/java/antipatterns/UserDao.java
    - work/refactoring-java/src/main/java/antipatterns/OrderRepository.java
    - work/refactoring-java/src/main/java/antipatterns/TransactionManager.java
    - work/refactoring-java/src/main/java/antipatterns/ReportGenerator.java
  modified:
    - .gitignore (work/* ignore + !work/refactoring-java/ 例外追加)
decisions:
  - "javac 単体でコンパイル疎通確認 (host に gradle 未導入): src/main/java/antipatterns/*.java を /tmp/rj-classes に -d 出力、exit 0 で 10 個の .class を生成"
  - "JDBC import は java.sql.* のみに限定し org.sqlite.JDBC は Class.forName 文字列経由でロード (sqlite-jdbc jar 無しでも javac が通る)"
  - "アンチパターンコメント方針: // BAD / // TODO:ダメ 等のメタ注釈禁止。コード本体は素っぽく書き、解説は README.md に集約 (リファクタリング修行部屋の AI が生のコード臭を感知できるように)"
  - "root .gitignore を修正して work/* ignore + !work/refactoring-java/ の例外追加。plan の「触らないもの」に .gitignore が含まれていたが、work/ ignore のままでは成果物をコミットできず blocker になるため Rule 3 (auto-fix blocking issues) として最小修正 (プロンプトでも「.gitignore 等の追加が必要なら判断すること」と明示許可あり)"
metrics:
  duration: "15 分程度"
  completed: "2026-04-21"
  tasks: 1
  files_created: 14
  files_modified: 1
---

# Quick 260421-uiu: refactoring-java アンチパターンカタログ Summary

`work/refactoring-java/` に Gradle + Java 17 の最小プロジェクト骨格と、`src/main/java/antipatterns/` 配下に 10 個のアンチパターン Java クラスを作成。後続「リファクタリング修行部屋」ミッションの題材として使う educational bad example。javac 17 でコンパイル疎通確認済 (exit 0、10 .class 生成)。

## 作成ファイル (14 個)

### Gradle / メタ (4)
- `work/refactoring-java/settings.gradle` — `rootProject.name = 'refactoring-java'`
- `work/refactoring-java/build.gradle` — java + application plugin、Java 17 toolchain、sqlite-jdbc 3.45.1.0、mainClass = `antipatterns.Main`
- `work/refactoring-java/.gitignore` — Gradle 標準 (.gradle/ build/ *.class *.log .idea/ *.iml 等)
- `work/refactoring-java/README.md` — 116 行、実験素材である旨の警告 + ビルド方法 + 10 ファイル各々のアンチパターン列挙 + 今後の展開

### Java 10 ファイル (`src/main/java/antipatterns/`)

各ファイルに埋め込んだアンチパターン (後続のリファクタリング修行部屋ミッション設計で参照用):

#### `DatabaseConnection.java`
- URL / USER / PASSWORD を `private static final` でハードコード (`jdbc:sqlite:/tmp/app.db`, `admin`, `admin1234`)
- `private static Connection conn` を使い回し、lazy init で null チェック (スレッド非安全)
- `close()` メソッド不在 → 接続がプロセス終了まで開きっぱなし
- Connection 取得失敗時は println してそのまま null 返却

#### `LegacyFileReader.java`
- `new FileReader(path)` を try-with-resources 無しで開く
- `catch (IOException e) { }` で例外完全握り潰し
- `BufferedReader.readLine()` を while で回し `String` の `+` 連結 (StringBuilder 不使用)
- `readFirstLine()` では Reader を完全に開きっぱなしのまま return

#### `CsvParser.java`
- `line.split(",")` のみで CSV 扱い (引用符・カンマエスケープ無視)
- `cols[0]` / `cols[1]` / `cols[2]` / `cols[3]` のインデックス直打ち
- 不正入力時は `return null;` (呼び出し側 NPE リスク)
- 列数 3 未満も `null` 返し

#### `LogWriter.java`
- static `FileWriter fw` を `new FileWriter("app.log", true)` で開きっぱなし
- static `SimpleDateFormat FMT` をスレッド非安全に共有
- `log()` 内で `System.out.println` + `fw.write` を同時実行 (二重出力)
- static initializer の失敗を println するだけ

#### `ConfigLoader.java`
- ハードコードパス `/etc/app/config.properties`
- static `Map<String,String> cache` にキャッシュ → リロード手段なし
- `FileInputStream` を close せず `Properties#load` のみ呼ぶ
- `getInt()` で `NumberFormatException` を `RuntimeException("bad int: ...")` にラップ (スタックトレース欠落)

#### `UserDao.java`
- `"SELECT * FROM users WHERE name = '" + name + "'"` の生 SQL 文字列連結 (SQL Injection)
- `private static Statement stmt` を使い回し
- ResultSet を `HashMap<String,Object>` に詰め替え (型消失)
- `close()` / `finally` が全メソッドで一切無い
- `SELECT *` の濫用 (3 メソッド中 2 箇所)
- `deleteByName` も文字列連結

#### `OrderRepository.java`
- `findById` 毎に `getConnection()` を呼ぶが close しない (接続リーク)
- `findAll()` が `List<Map<String,Object>>` を返す (Domain Model 不在)
- `findOrdersByUserId(userId)` が `findAll()` 結果を Java 側で全件フィルタ (DB の WHERE 不使用)
- `totalAmountForUser` で `String.valueOf` 比較 + `Double.parseDouble` (型の三段階変換)

#### `TransactionManager.java`
- `private static boolean inTransaction` で状態管理 (並列呼び出しで壊れる)
- `begin()` / `commit()` / `rollback()` の対称性崩壊
- `rollback()` が `catch (Exception e) { }` で例外を完全に食う
- `commit()` で例外時に `setAutoCommit(true)` に戻さない

#### `ReportGenerator.java`
- `SELECT * FROM orders` の生 SQL 実行
- `PrintWriter(new FileWriter(outputPath))` を close せず `flush()` のみ
- SQL 発行 → 集計 → フォーマット → ファイル書き込みを 1 メソッドに混在
- シグネチャが `throws Exception` で雑に上に投げる
- `Double.parseDouble(a.toString())` で金額集計

#### `Main.java`
- `public static void main(String[] args) throws Exception` に「設定ロード → DB 接続 → UserDao → CSV → OrderRepository → TransactionManager → ReportGenerator → LogWriter」を一気通貫で詰め込んだ God method (74 行)
- 局所変数名: `a`, `tmp`, `c`, `i`, `r`, `p`, `or`, `rg`
- `if (a != null && a.size() > 0 && a.get("id") != null)` 型の防御ネスト
- `try { commit() } catch (Exception e) { rollback() }` の広すぎる catch
- 例外は全て `throws Exception` で上に丸投げ

**合計アンチパターン数**: 10 ファイルで 40+ (1 ファイル平均 4 個)

## ビルド疎通確認

host 環境:
- `javac -version` → `javac 17.0.13` (Temurin-17.0.13+11) ✅
- `gradle` → 未インストール (plan フォールバック通り javac で検証)

実行コマンド:
```bash
cd work/refactoring-java
mkdir -p /tmp/rj-classes && rm -rf /tmp/rj-classes/*
javac -d /tmp/rj-classes src/main/java/antipatterns/*.java
# exit 0
ls /tmp/rj-classes/antipatterns/ | wc -l  # → 10
```

結果: **exit 0、10 個の .class 生成、warning のみ (error なし)**。JDBC 関連 import は `java.sql.*` のみに絞ったため、sqlite-jdbc jar 無しで javac 通過。`Class.forName("org.sqlite.JDBC")` は文字列なので静的検証されない。

## 検証結果

| 検証項目 | 結果 |
|----------|------|
| `settings.gradle` / `build.gradle` / `README.md` / `.gitignore` の 4 つが存在 | ✅ |
| `src/main/java/antipatterns/*.java` がちょうど 10 個 | ✅ |
| 全 10 ファイルが `package antipatterns;` 宣言を持つ | ✅ |
| `javac` で exit 0 コンパイル | ✅ (gradle は未導入) |
| README.md 40 行以上 | ✅ 116 行 |
| README.md 箇条書き 10 個以上 | ✅ 49 個 |
| アンチパターンスポットチェック (SELECT *, DriverManager.getConnection, catch (Exception e)) | ✅ 8 箇所ヒット |
| メタコメント (`BAD` / `TODO.*ダメ` / `わざと`) 不在 | ✅ 0 件 |
| `work/refactoring-java/` 以外への変更ゼロ | ⚠️ `.gitignore` のみ変更 (下記 Deviations 参照) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] ルート `.gitignore` に `work/` ignore ルールがあり、成果物が git に追加できない blocker**

- **Found during:** Task 1 コミット準備段階 (`git status --short --untracked-files=all` で `work/refactoring-java/` が表示されないことから発見)
- **Issue:** プラン制約「触らないもの: ルート `CLAUDE.md`, `.gitignore`, `README.md` 等」に `.gitignore` が含まれるが、`.gitignore:24` に `work/` が全体除外として存在し、このままでは本プラン成果物を一切コミットできない (UIU-01 〜 UIU-05 すべて未達となる)
- **Fix:** ルート `.gitignore` の `work/` を `work/*` に変更し、直下に `!work/refactoring-java/` の否定ルールを追加。これにより `work/refactoring-java/` のみ追跡許可、`work/blog-draft.md` 等の既存ファイルは引き続き ignore を維持
- **Files modified:** `.gitignore` (1 行削除、2 行追加)
- **Justification:** executor プロンプト側で「work/ ディレクトリ自体もリポジトリに新規作成される想定 (.gitignore 等の追加が必要なら判断すること)」と明示許可があり、プラン本体の「触らないもの」より上位の指示として解釈。最小限のスコープ (work/ 配下の他ファイルは影響なし) で修正
- **Commit:** cea45d7 (本タスクと同一コミットに含めた — blocker 解消なしにコミットできないため分割不可)

### Planned ≠ Actual な微調整

- **ブランチ名**: プラン想定 `chore/refactoring-java-sample` に対し、worktree の都合で実際のブランチ名は `chore/refactoring-java-sample` (commit が乗っているのは worktree の内部ブランチ)。worktree からの取り込み (squash merge) 時に orchestrator 側で調整される前提
- **build.gradle の実ビルド**: host に gradle 未導入のため gradle build は実行できず、plan の fallback 通り javac で代替。build.gradle の構文は plan の推奨骨格そのまま採用しているため gradle が入っている環境では通る想定

## Authentication Gates

なし。

## Deferred Items / Next Steps (今回スコープ外)

1. **テストデータ (SQLite schema + seed)**: `users` / `orders` テーブルの DDL と seed データを別 Quick で追加予定。現状は DB ファイルが無いので実行時に SQLException で落ちる (アンチパターンの一部として意図通り)
2. **gradle wrapper (`gradlew`) 同梱**: 現状は `gradle` コマンド直接使用を想定。gradle 入っていない環境向けに `./gradlew` を生成して同梱する拡張は別タスク
3. **Mr.ポポ「リファクタリング修行部屋」スキル整備**: `spirit-room-manager/skills/` にリファクタリング部屋ヒアリング + MISSION.md 生成スキルを追加する (別 Phase or 別 Quick で)
4. **トレーニングシナリオ設計**: 「全ファイル読解 → 問題リスト化 → 依存薄い箇所から直す → テスト整備 → ドメインモデル抽出」の段階シナリオを catalog.md に書く
5. **到達度評価機構**: before/after diff、追加テスト数、SpotBugs / PMD などの静的解析スコアで修行達成度を測る仕組み

## Known Stubs

なし (全メソッド実体を持ち、コンパイル通過 + 実行可能 — ただし実行時は DB 未整備で落ちるのが意図)。

## Commits

| Commit | Message | Files |
|--------|---------|-------|
| cea45d7 | `chore(quick/260421-uiu): add refactoring-java antipattern sample (gradle + 10 java files)` | 15 files changed, 667 insertions(+), 1 deletion(-) |

## Self-Check: PASSED

- 14 個の成果物ファイル存在確認済 (`settings.gradle`, `build.gradle`, `.gitignore`, `README.md`, 10 個の `.java`)
- コミット `cea45d7` が git log に存在
- `javac -d /tmp/rj-classes src/main/java/antipatterns/*.java` → exit 0、10 個の `.class` 生成
- 10 個の `.java` すべてが `package antipatterns;` 宣言を持つ
- メタコメント (`BAD` / `TODO.*ダメ` / `わざと`) 0 件
- アンチパターンスポットチェック (`SELECT *` / `DriverManager.getConnection` / `catch (Exception e)`) 8 箇所ヒット
