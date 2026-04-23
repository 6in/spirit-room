---
phase: quick-260421-uiu
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - work/refactoring-java/settings.gradle
  - work/refactoring-java/build.gradle
  - work/refactoring-java/README.md
  - work/refactoring-java/.gitignore
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
autonomous: true
requirements:
  - UIU-01  # Gradle プロジェクト (build.gradle / settings.gradle) が置かれ、Java 17 でビルドが通る
  - UIU-02  # src/main/java/antipatterns/ 配下に 10 ファイルの .java を配置 (Main + DatabaseConnection + File I/O 4 + DB アクセス 4)
  - UIU-03  # 各ファイルは意図的にアンチパターンを含む (ハードコード・God class・生 JDBC・例外握り潰し等) が、コンパイルは通ること
  - UIU-04  # README.md にリファクタリング実験用である旨と各ファイルのアンチパターン一覧を記載
  - UIU-05  # JDBC 依存は sqlite-jdbc を Gradle 経由で取得 (DB ファイル実在不要、実行時に落ちるのは OK)

must_haves:
  truths:
    - "work/refactoring-java/ で `gradle build` (または gradle wrapper があれば `./gradlew build`) が exit 0 で成功する"
    - "src/main/java/antipatterns/ に .java ファイルが 10 個存在し、すべて `javac` が通る (= コンパイルエラーゼロ)"
    - "各 .java ファイルはパッケージ `antipatterns` を宣言し、ファイル名とクラス名が一致する"
    - "README.md を読むと「リファクタリング実験用の意図的にダメなコード」である旨と 10 ファイル各々のアンチパターン概要が分かる"
    - "アンチパターンは `// TODO: これはダメ!` のようなメタコメントではなく、実コードとして自然に埋め込まれている (資格情報ハードコード、生 SQL 文字列連結、例外握り潰し、static 可変状態、God class 等の「実在する昭和〜平成初期の Java コード」の臭いがする)"
  artifacts:
    - path: "work/refactoring-java/settings.gradle"
      provides: "rootProject.name = 'refactoring-java' 宣言"
      contains: "rootProject.name"
    - path: "work/refactoring-java/build.gradle"
      provides: "Gradle java plugin + Java 17 toolchain + sqlite-jdbc 依存"
      contains: "sourceCompatibility"
    - path: "work/refactoring-java/README.md"
      provides: "実験用ダメコードであることの宣言 + 10 ファイルのアンチパターン一覧"
      min_lines: 40
    - path: "work/refactoring-java/src/main/java/antipatterns/Main.java"
      provides: "全部入り God class (public static void main)"
      contains: "public static void main"
    - path: "work/refactoring-java/src/main/java/antipatterns/DatabaseConnection.java"
      provides: "資格情報ハードコード + static 可変状態の JDBC 接続クラス"
      contains: "DriverManager"
  key_links:
    - from: "work/refactoring-java/build.gradle"
      to: "org.xerial:sqlite-jdbc"
      via: "dependencies { implementation ... }"
      pattern: "sqlite-jdbc"
    - from: "src/main/java/antipatterns/Main.java"
      to: "DatabaseConnection / UserDao / LegacyFileReader"
      via: "直接 new / static メソッド呼び出し (God class の呼び出し網)"
      pattern: "new (DatabaseConnection|UserDao|LegacyFileReader)|DatabaseConnection\\."
    - from: "src/main/java/antipatterns/UserDao.java"
      to: "DatabaseConnection.getConnection()"
      via: "static 取得 + 生 SQL 文字列連結"
      pattern: "DatabaseConnection\\.getConnection"
---

<objective>
`work/refactoring-java/` 配下に、Gradle でビルドできる意図的にダメな Java プロジェクト (アンチパターンカタログ) を 1 発で作成する。これは後続の「リファクタリング部屋」ミッション (AI 修行部屋タイプの拡張) の**実験対象**として使うサンプル素材であり、今回はファイル配置とビルド疎通まで。テストデータ作成・リファクタリング指示書・修行シナリオ整備は後続タスク。

Purpose: 「精神と時の部屋」の第二のミッションタイプ (POC 実装ではなくリファクタリング修行) を成立させるには、AI に「これを直せ」と突き付けられる題材が必要。わざとらしい `// TODO: BAD` コメントではなく、現場で本当に出会うレベルの臭いコード — 資格情報ハードコード・static 可変状態・例外握り潰し・生 SQL 文字列連結・God class・try-with-resources 不使用・マジックナンバー・責務混在 — を散りばめた 10 ファイルを用意する。ビルドが通ることで AI は「コンパイルは通るがコードレビュー的に NG な例」として正しく受け取れる。

Output: `work/refactoring-java/` 配下に Gradle プロジェクト一式 (settings.gradle / build.gradle / .gitignore / README.md / src/main/java/antipatterns/*.java × 10)。新規作成のみ、既存ファイルの書き換えなし。
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@/home/parallels/workspaces/spirit-room-full/CLAUDE.md

<interfaces>
<!-- このプランは完全新規作成で、既存コードへの import/依存は無い。 -->
<!-- ただし「Gradle + Java 17 + SQLite JDBC の最小構成」は executor が迷わないように逐語で embed する。 -->

### 推奨 build.gradle の骨格 (executor はこれをそのまま出発点にして良い)

```gradle
plugins {
    id 'java'
    id 'application'
}

group = 'antipatterns'
version = '0.1.0'

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.xerial:sqlite-jdbc:3.45.1.0'
}

application {
    mainClass = 'antipatterns.Main'
}
```

### settings.gradle

```gradle
rootProject.name = 'refactoring-java'
```

### .gitignore (Gradle 標準)

```
.gradle/
build/
*.class
*.log
.idea/
*.iml
*.ipr
*.iws
out/
```

### ディレクトリレイアウト

```
work/refactoring-java/
├── settings.gradle
├── build.gradle
├── .gitignore
├── README.md
└── src/main/java/antipatterns/
    ├── Main.java                  # God class + 責務混在 + public static void main
    ├── DatabaseConnection.java    # 資格情報ハードコード + static Connection 使い回し
    ├── LegacyFileReader.java      # FileReader を close しない + 例外握り潰し
    ├── CsvParser.java             # split(",") + インデックスマジックナンバー + null 返し
    ├── LogWriter.java             # System.out + FileWriter を close しない + static Date フォーマット
    ├── ConfigLoader.java          # Properties をロードしっぱなし + ハードコードパス + static キャッシュ
    ├── UserDao.java               # 生 SQL 文字列連結 (SQL Injection) + Statement 使い回し
    ├── OrderRepository.java       # finally で close しない + ResultSet を Map に詰め替えるだけ + N+1 を誘発する API
    ├── TransactionManager.java    # commit/rollback の対称性崩壊 + static boolean isInTransaction
    └── ReportGenerator.java       # PrintWriter 開きっぱなし + SELECT * + 生 SQL + ビジネスロジック混在
```

### アンチパターン「ガイドライン」(executor はこれを参考に自然なコードを書く)

各ファイルに 2〜4 個のアンチパターンを散りばめる。わざとらしい `// BAD:` コメントは禁止。普通のコードとして書き、レビュアーの目で「あっ…」となるのが理想。

| ファイル | 埋め込むアンチパターン (例) |
|---------|-----------------------------|
| DatabaseConnection.java | (1) URL/USER/PASSWORD が `private static final String` でハードコード (2) `private static Connection conn` を使い回し (3) `getConnection()` で毎回 null チェックして lazy init (4) close() が存在しない |
| LegacyFileReader.java | (1) `new FileReader(path)` を try-with-resources 無しで開く (2) `catch (IOException e) { }` で握り潰し (3) BufferedReader の `readLine()` を while で回し String 連結 (StringBuilder 不使用) |
| CsvParser.java | (1) `line.split(",")` だけで CSV 扱い (引用符・カンマエスケープ無視) (2) `cols[0]`, `cols[1]`, `cols[2]` のインデックス直打ち (3) 失敗時に `return null;` |
| LogWriter.java | (1) `FileWriter fw = new FileWriter("app.log", true);` を static フィールドで開きっぱなし (2) `SimpleDateFormat` を static で共有 (スレッド非安全) (3) `System.out.println` と併用 (二重出力) |
| ConfigLoader.java | (1) `Properties p = new Properties(); p.load(new FileInputStream("/etc/app/config.properties"));` のハードコードパス (2) static Map にキャッシュして更新手段なし (3) `getInt()` で `Integer.parseInt` し NumberFormatException を RuntimeException にラップ |
| UserDao.java | (1) `"SELECT * FROM users WHERE name = '" + name + "'"` で生 SQL 文字列連結 (2) `Statement` を `static` で使い回し (3) ResultSet を `HashMap<String,Object>` に詰め替えて返す (型消失) (4) `close()` 無し |
| OrderRepository.java | (1) `findById` ごとに `getConnection()` を呼ぶが close しない (コネクションリーク) (2) `findAll()` が `List<Map<String,Object>>` を返す (3) `findOrdersByUserId(userId)` を `findAll` 結果から Java 側でフィルタ (N+1 ではなく「全取得からの絞り込み」アンチパターン) |
| TransactionManager.java | (1) `private static boolean inTransaction` で状態管理 (並列呼び出しで壊れる) (2) `begin()` と `commit()` は Connection#setAutoCommit(false) / commit() を呼ぶが `rollback()` が例外を食って何もしない (3) try/finally の対称性が無い |
| ReportGenerator.java | (1) `SELECT *` の生 SQL を実行 (2) `PrintWriter pw = new PrintWriter(new FileWriter("report.txt"));` を close せず `flush()` のみ (3) SQL 発行 → 集計 → フォーマット → ファイル書き込みを 1 メソッドで混在 (4) 例外は `throws Exception` |
| Main.java | (1) `public static void main` の中に「設定ロード → DB 接続 → 全 DAO 呼び出し → CSV 読み込み → レポート出力 → ログ書き込み」を一気通貫で書く God method (2) 局所変数名が `a`, `tmp`, `i` (3) 深いネスト (4) `if (users != null && users.size() > 0 && ...)` 型の防御ネスト |

### 重要な技術メモ (executor 向け)

- **コンパイル通過が MUST**: sqlite-jdbc 依存を `build.gradle` に入れておくので `java.sql.*` / `org.sqlite.*` は import できる。`DatabaseConnection.java` では `Class.forName("org.sqlite.JDBC")` または暗黙ロードどちらでも良いが、**try/catch は通るように書く**。
- **実行時に DB ファイルが無くて落ちるのは OK**: これ自体がアンチパターンの 1 つ (事前チェック無し)。
- **未使用 import / 警告は気にしない**: javac warning は OK。error は NG。
- **@SuppressWarnings は付けない**: レビュアーに警告が見える方がリファクタリング題材として良い。
- **`throws Exception` を signature に書くのは許容**: それ自体がアンチパターンなので積極的に使って良い。
- **Javadoc は不要**: コード本体だけで 1 ファイル 30〜80 行程度を目安にする (あまり短いと「臭い」が出ない、長すぎると読むのが大変)。
- **日本語コメントは控えめに**: 本物の「現場コード」っぽさを出すため、コメントは英語 or 数行の無味乾燥な日本語で OK。わざとらしい説明コメントは入れない (README で説明する)。
- **CLAUDE.md の命名規約は bash 向け**: Java 側は Java 標準 (クラス UpperCamelCase、メソッド lowerCamelCase、定数 UPPER_SNAKE) を使う。
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Gradle プロジェクト骨格 + アンチパターン 10 ファイル + README を一括生成</name>
  <files>
work/refactoring-java/settings.gradle
work/refactoring-java/build.gradle
work/refactoring-java/.gitignore
work/refactoring-java/README.md
work/refactoring-java/src/main/java/antipatterns/Main.java
work/refactoring-java/src/main/java/antipatterns/DatabaseConnection.java
work/refactoring-java/src/main/java/antipatterns/LegacyFileReader.java
work/refactoring-java/src/main/java/antipatterns/CsvParser.java
work/refactoring-java/src/main/java/antipatterns/LogWriter.java
work/refactoring-java/src/main/java/antipatterns/ConfigLoader.java
work/refactoring-java/src/main/java/antipatterns/UserDao.java
work/refactoring-java/src/main/java/antipatterns/OrderRepository.java
work/refactoring-java/src/main/java/antipatterns/TransactionManager.java
work/refactoring-java/src/main/java/antipatterns/ReportGenerator.java
  </files>
  <action>
Write ツールで以下 14 ファイルを新規作成する。既存ファイルは無いので上書き衝突は発生しない。**作成順は任意** (並列で作っても OK) だが、作り終えた後に**必ず下記の「ビルド疎通確認」を実行する**。

### Step 1: Gradle 骨格 (3 ファイル)

1. **`work/refactoring-java/settings.gradle`**
   ```gradle
   rootProject.name = 'refactoring-java'
   ```

2. **`work/refactoring-java/build.gradle`** — `<interfaces>` の推奨骨格そのまま (Java 17 toolchain + sqlite-jdbc + application plugin + mainClass = `antipatterns.Main`)。

3. **`work/refactoring-java/.gitignore`** — `<interfaces>` の .gitignore ブロックそのまま。

### Step 2: アンチパターン Java × 10 ファイル

`src/main/java/antipatterns/` 配下に **10 個の .java ファイル** を作成する。すべて:

- パッケージ宣言 `package antipatterns;` を先頭に置く
- ファイル名とクラス名を一致させる (`public class UserDao` → `UserDao.java`)
- 必要な import を**きちんと書く** (import ミスでコンパイル失敗は NG)
- 各ファイルのアンチパターンは `<interfaces>` の表を参考に**自然に埋め込む** (わざとらしい `// BAD:` コメントは禁止)
- 30〜80 行程度を目安にする (短すぎず長すぎず)

**各ファイルの最低実装要件** (コンパイル通過のため):

- **DatabaseConnection.java**: `getConnection()` が `Connection` を返す static メソッドとして存在。URL は `jdbc:sqlite:/tmp/app.db` のようなハードコード。`Class.forName` or 暗黙ロード、例外は try/catch で潰すか `throws` する。
- **LegacyFileReader.java**: `readAll(String path)` が `String` を返す。内部で FileReader + BufferedReader を try-with-resources **なしで**開き、例外は空 catch で握り潰す。
- **CsvParser.java**: `parse(String line)` が `String[]` または `Map<String,String>` を返す。`line.split(",")` のみ使用。不正入力時に `return null;`。
- **LogWriter.java**: static `FileWriter` を持つ。`log(String msg)` メソッドが `System.out.println` と file 書き込みを同時に行う。static `SimpleDateFormat`。
- **ConfigLoader.java**: `load()` が `Properties` をファイルから読む。static `Map<String,String> cache`。`getInt(String key)` で `Integer.parseInt`。
- **UserDao.java**: `findByName(String name)` が `Map<String,Object>` を返す。SQL は `"SELECT * FROM users WHERE name = '" + name + "'"` の文字列連結。`Statement` を使う (PreparedStatement ではない)。`DatabaseConnection.getConnection()` を呼ぶ。
- **OrderRepository.java**: `findById(long id)` と `findAll()` と `findOrdersByUserId(long userId)` の 3 メソッド。`findOrdersByUserId` は `findAll()` 結果を Java 側で `if (order.get("user_id").equals(userId))` フィルタ。
- **TransactionManager.java**: static `boolean inTransaction`、`begin()` / `commit()` / `rollback()`。`rollback` は try/catch で例外を食う。
- **ReportGenerator.java**: `generate(String outputPath)` が `void`、`throws Exception`。`DatabaseConnection.getConnection()` → `SELECT * FROM orders` → `PrintWriter(new FileWriter(outputPath))` で書き込み、最後に `pw.flush()` のみで close しない。
- **Main.java**: `public static void main(String[] args) throws Exception` の中で `ConfigLoader.load()` → `DatabaseConnection.getConnection()` → `new UserDao().findByName("alice")` → `new OrderRepository().findAll()` → `new CsvParser().parse(...)` → `new ReportGenerator().generate(...)` → `LogWriter.log(...)` を順に呼ぶ God method。局所変数は `a`, `tmp`, `i` などに。例外はすべて main の `throws Exception` で上に投げる。

**コンパイル通過のための相互参照ルール**:
- Main.java からの呼び出し先シグネチャは、executor が上記仕様から自分で**矛盾しないように**決めて構わない (どちらかを書いてからもう一方を合わせる)。
- 存在しないメソッドを呼んで `javac` で落ちるのだけは絶対避ける。

### Step 3: README.md

`work/refactoring-java/README.md` を作成する。内容は最低限以下を含む (min 40 行):

- タイトル: `# refactoring-java — アンチパターンカタログ (リファクタリング実験用)`
- **警告セクション**: このプロジェクトは「精神と時の部屋」のリファクタリング修行部屋向け実験素材であり、**本番で真似してはいけない**コードを集めた educational bad example であることを明記。
- **ビルド方法**: `./gradlew build` (wrapper を同梱しない場合は `gradle build`、Java 17 必須) と `./gradlew run` (実行は DB が無いと落ちる旨 — それもアンチパターンの一部)。
- **ファイル一覧と埋め込みアンチパターン** (10 ファイル × 箇条書き 2〜4 個ずつ): `<interfaces>` の表と同等の情報を Markdown 表 or 箇条書きで。
- **今後の展開 (今回のスコープ外)**: (1) テストデータ / SQLite schema を別 Quick で追加予定 (2) Mr. ポポのリファクタリング部屋スキル整備 (3) AI がこのプロジェクトを `/workspace` に受け取り、段階的に改善するトレーニングシナリオ。

### Step 4: ビルド疎通確認 (executor が自分で実行する)

ファイル作成後、以下のいずれかで**コンパイル通過**を確認する:

- **Gradle が host に有る場合**: `cd work/refactoring-java && gradle build --offline` で済めばベスト。オフラインが効かないなら通常の `gradle build`。
- **Gradle が無い場合**: `cd work/refactoring-java && javac -d /tmp/rj-classes src/main/java/antipatterns/*.java` でコンパイルだけ確認する (sqlite-jdbc を使う箇所は `java.sql.*` なので JDK 標準で通る。`org.sqlite.JDBC` を **直接** import している場合は `-cp` に jar が必要 — 原則 `Class.forName("org.sqlite.JDBC")` 文字列呼び出しにして **import は `java.sql.*` のみ**にしておくと JDK 単体で javac が通る)。
- どちらも無ければ `bash -c "command -v javac"` で javac 確認 → 上記 `javac` で疎通。

**重要**: コンパイルで落ちるパッケージ宣言ミス・import 不足・メソッドシグネチャ不整合があれば**修正してから完了とする**。実行時例外は **OK** (DB ファイル未作成・ファイル I/O 失敗で落ちるのはアンチパターンの一部として成立)。

### 触らないもの (明示)

- 既存の `spirit-room/`, `spirit-room-manager/`, `.planning/` 配下一切。
- `work/` 配下の既存ファイル (`blog-draft.md` 等)。
- ルート `CLAUDE.md`, `.gitignore`, `README.md` 等。
  </action>
  <verify>
    <automated>test -f work/refactoring-java/settings.gradle && test -f work/refactoring-java/build.gradle && test -f work/refactoring-java/README.md && test -f work/refactoring-java/.gitignore && ls work/refactoring-java/src/main/java/antipatterns/*.java | wc -l | awk '$1==10{exit 0} {exit 1}' && grep -l "^package antipatterns;" work/refactoring-java/src/main/java/antipatterns/*.java | wc -l | awk '$1==10{exit 0} {exit 1}' && (cd work/refactoring-java && (command -v gradle >/dev/null && gradle -q --console=plain build -x test 2>&1 || (mkdir -p /tmp/rj-classes && javac -d /tmp/rj-classes src/main/java/antipatterns/*.java 2>&1)))</automated>

Checks (AND で全部通ること):
1. 4 つのトップレベルファイル (settings.gradle / build.gradle / README.md / .gitignore) が存在
2. `src/main/java/antipatterns/*.java` が **ちょうど 10 個**
3. 全 10 ファイルが `package antipatterns;` 宣言を持つ (= パッケージとディレクトリの一致)
4. Gradle が有れば `gradle build -x test` が exit 0 / 無ければ `javac -d /tmp/rj-classes ...` が exit 0 (= コンパイル通過)
  </verify>
  <done>
- `work/refactoring-java/` 配下に settings.gradle / build.gradle / .gitignore / README.md の 4 ファイル + `src/main/java/antipatterns/` 配下に 10 個の .java が存在
- Gradle build (または javac 直) でコンパイルが通る (warning は OK、error は NG)
- README.md に「リファクタリング実験用のダメコード集」である旨と 10 ファイル各々のアンチパターン概要が書かれている
- 各 Java ファイルがパッケージ `antipatterns` を宣言し、クラス名とファイル名が一致
- アンチパターンは自然にコードに埋め込まれている (`// BAD:` や `// TODO: これはダメ` のようなメタコメントが無い)
- `work/refactoring-java/` 以外への変更がゼロ (git status で確認可)
  </done>
</task>

</tasks>

<verification>
マニュアル検証 (quick task なので developer が最終確認):

1. **ファイル構成**:
   ```bash
   tree work/refactoring-java/ -I 'build|.gradle'
   # → settings.gradle, build.gradle, .gitignore, README.md, src/main/java/antipatterns/*.java × 10
   ```

2. **コンパイル疎通** (Gradle がある環境):
   ```bash
   cd work/refactoring-java && gradle build -x test
   # → BUILD SUCCESSFUL
   ```
   Gradle が無ければ:
   ```bash
   cd work/refactoring-java && mkdir -p /tmp/rj && javac -d /tmp/rj src/main/java/antipatterns/*.java
   # → 終了コード 0 (warning は OK)
   ```

3. **アンチパターン品質スポットチェック**:
   ```bash
   grep -n "SELECT \* FROM\|DriverManager\.getConnection\|catch (Exception e) {" work/refactoring-java/src/main/java/antipatterns/*.java
   # → 最低 1 ファイルで SQL ワイルドカード / 生 JDBC / 広い catch が出現
   grep -l "BAD\|TODO.*ダメ\|わざと" work/refactoring-java/src/main/java/antipatterns/*.java
   # → ヒットゼロ (わざとらしいメタコメント禁止の検証)
   ```

4. **README 品質**:
   ```bash
   wc -l work/refactoring-java/README.md
   # → 40 行以上
   grep -c "^-\|^\*" work/refactoring-java/README.md
   # → 10 以上 (各ファイルのアンチパターン箇条書き)
   ```

5. **他ディレクトリに影響無し**:
   ```bash
   git status --short | grep -v '^?? work/refactoring-java/' | grep -v '^$'
   # → 何も出ない (work/refactoring-java/ 以外の新規/変更ゼロ)
   ```
</verification>

<success_criteria>
- `work/refactoring-java/` 配下に Gradle プロジェクトが成立し、`gradle build -x test` (または `javac` 直) が exit 0
- `src/main/java/antipatterns/` に 10 個の .java ファイル、全て `package antipatterns;` 宣言
- 10 ファイル合計で最低 20 個以上のアンチパターンが埋め込まれている (1 ファイル平均 2〜4 個)
- アンチパターンは `// BAD:` / `// TODO:ダメ` のようなメタ注釈ではなく、実コードとして自然 (レビュー視点で「臭う」)
- README.md がリファクタリング実験用の宣言と 10 ファイル分のアンチパターン概要を含む
- ブランチ `chore/refactoring-java-sample` 上でのみ変更、`work/refactoring-java/` 以外の変更ゼロ
- テストデータ (SQLite schema / seed) は **含めない** (後続タスク)
</success_criteria>

<output>
完了後、`.planning/quick/260421-uiu-work-refactoring-java-java-10-gradle/260421-uiu-SUMMARY.md` を作成し、
- 作成ファイル 14 個のリスト
- 各 Java ファイルに埋め込んだアンチパターンの簡潔な列挙 (後続の「リファクタリング部屋」ミッション設計で参照できるよう)
- ビルド疎通確認方法 (Gradle か javac か) とその結果
- 今回スコープ外としたもの (テストデータ・DB schema・Mr.ポポ向けリファクタリング修行スキル) を「Next Steps」として明記
を記録する。
コミットはブランチ `chore/refactoring-java-sample` 上に 1 本 (`chore(quick/260421-uiu): add refactoring-java antipattern sample (gradle + 10 java files)`) を想定。
</output>
