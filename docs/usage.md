# 使い方

`dratools` はサブコマンド方式です。コマンド一覧は `dratools --help` で確認できます。各コマンドのオプションは `dratools <command> --help` で確認できます。

親 accession を扱うときの設定は [環境変数](environment.md) にまとめています。

## インストール

```sh
gem install dratools
```

開発中のリポジトリからインストールする場合は、次の手順を実行します。

```sh
git clone https://github.com/kojix2/dratools
cd dratools
bundle install
bundle exec rake install
```

## コマンド一覧

| コマンド | 役割 |
| --- | --- |
| `url`   | ダウンロード URL を表示する（`--tsv` で TAB 区切り列、`--json` で JSON 出力） |
| `get`   | ファイルをダウンロードする |
| `probe` | 短時間の接続確認だけを行う |
| `tree`  | accession から run へ辿る探索ツリーを表示する |
| `meta`  | レコードのメタ情報を表示する（`--json` で生 JSON） |
| `runs`  | run accession の一覧を出力する |
| `size`  | ダウンロード合計サイズを集計する |

コマンド名は基本的に単数形です。一覧を返す `runs` だけが複数形です。`run` は「実行する」と読み間違えやすいためです。打ち間違いに備えて別名も使えます。`run` は `runs`、`urls` は `url`、`sizes` は `size`、`trees` は `tree` として扱います。ヘルプとエラーとバナーには、表の正規名だけを表示します。

## メタ情報を表示する (`meta`)

`meta` は DDBJ Search の resource JSON を要約して表示します。

```sh
dratools meta DRR300000
```

生の JSON を見る場合は `--json` を付けます。

```sh
dratools meta --json DRR300000
```

サイズは DDBJ Search API だけでは分かりません。`meta` はサイズを表示しません。容量は `size` で確認します。

run accession のレコードには platform や libraryStrategy が含まれないことがあります。実験条件を見たい場合は experiment accession も確認してください。

`runs:` は run 数を表示する行です。run と experiment の関係から分かるときだけ表示します。BioProject や BioSample では run 数を表示しません。これらのレコードで多数の探索を始めないためです。run の一覧が必要な場合は `runs` を使ってください。

## run 一覧を表示する (`runs`)

`runs` は accession を run accession の一覧に展開します。

```sh
dratools runs PRJNA341783
```

出力は1行1件です。`get` にそのまま渡せます。

```sh
dratools runs PRJNA341783 | dratools get -O ~/Downloads
```

Study や BioProject には多数の experiment や sample が含まれることがあります。`runs` はこれらを無制限には辿りません。上限を超えるとエラーで止まります。run へ直接リンクがある場合は、100 件を超えても制限の対象外です。レコードが大きい場合は、先に `tree` や `meta` で構造を確認してください。experiment や sample に絞ってから `runs` を使ってください。

## 合計サイズを確認する (`size`)

`size` は実ファイルの URL に HTTP `HEAD` を送ります。`Content-Length` を合計します。FASTQ はディレクトリ URL で返ることがあります。その場合はディレクトリ一覧から `*.fastq*` を取り出します。取り出した各ファイルに `HEAD` を送ります。

```sh
dratools size PRJNA341783
```

出力は1行1件です。各行は accession、ファイル数、合計サイズ、`unresolved` 数を並べます。区切りは TAB です。先頭に `#` で始まるヘッダ行が付きます。合計サイズだけを取り出すには `cut -f3` を使います。ヘッダを除くには `grep -v '^#'` を使います。サイズを1つも取得できなかった行は、size 列を `NA` にします。accession を複数渡すと、最後に `total` 行が付きます。

```text
#accession	files	size	unresolved
DRR000001	1	1.0 KiB	0
```

既定では accession 1 件につき1行です。親 accession の場合は配下をすべて合算します。`--per-run`（`-r`）を付けると、run accession ごとに分けて集計します。これは `dratools runs XXX | xargs dratools size` と同じ結果です。1 コマンドで実行できます。

```sh
dratools size --per-run DRX000001
```

`--per-run` のとき、`total` 行は標準エラーに出します。標準出力には集計行だけが残ります。`awk` で合計するときに `total` 行を二重に数えないためです。

```text
#accession	files	size	unresolved
DRR000001	2	1.2 GiB	0
DRR000002	1	0.8 GiB	0
```

バイト数で表示する場合は `--bytes` を付けます。

```sh
dratools size --bytes PRJNA341783
```

JSON で表示する場合は `--json` を付けます。

```sh
dratools size --json PRJNA341783
```

`size` はネットワークにアクセスします。サイズを取得できないファイルは `unresolved` に数えます。direct run を多数持つ親 accession は、暗黙には展開しません。上限を超えるとエラーで止まります。先に `runs` で一覧を確認してください。範囲を絞ってから `size` を実行してください。

## URL を表示する (`url`)

`url` は `.sra` の URL を表示します。

```sh
dratools url DRR000001
```

FTP URL を優先する場合は `--protocol ftp` を付けます。
ftp URL が無いレコードでは https URL を表示します。

```sh
dratools url --protocol ftp DRR000001
```

FASTQ を探す場合は `--type fastq` を付けます。

```sh
dratools url --type fastq DRR000001
```

FASTQ はディレクトリ URL で返ることがあります。その URL は `url` と `tree` で確認できます。`get` は単一ファイルとして保存できません。この場合 `get` はエラーにします。

direct run を多数持つ親 accession は、暗黙には展開しません。上限を超えるとエラーで止まります。先に `runs` で一覧を確認してください。範囲を絞ってから `url` を実行してください。

`--tsv` を付けると、列を TAB 区切りで表示します。列は `run_accession`、`type`、URL、`size`、`md5` です。先頭に `#` で始まるヘッダ行が付きます。`size` と `md5` が無い場合は `NA` にします。

```text
#run_accession	type	url	size	md5
DRR000001	sra	https://...DRR000001.sra	1024	abc123
```

特定の列を取り出すには `grep -v '^#'` と `cut` を組み合わせます。

```sh
dratools url --tsv DRR000001 | grep -v '^#' | cut -f3
```

JSON で表示する場合は `--json` を付けます。

```sh
dratools url --json DRR000001
```

## 接続確認 (`probe`)

`probe` は接続確認だけを行います。ファイルをダウンロードしません。

```sh
dratools probe --timeout 5 DRR000001
```

接続できた URL は標準出力に表示します。形式は `OK<TAB>URL` です。`probe ... | grep OK` のように使えます。接続に失敗した accession は、エラーを標準エラーに出します。

## 探索ツリー (`tree`)

`tree` は accession から run までの経路を表示します。

```sh
dratools tree PRJNA341783
```

対象のファイル種別が見つからない理由を調べるときにも使えます。

```sh
dratools tree --type fastq PRJNA341783
```

direct run を多数持つ親 accession では、`tree` は各 run を個別取得しません。run の件数だけを表示します。run accession の全リストが必要な場合は `runs` を使ってください。

## ダウンロード (`get`)

`get` はファイルをダウンロードします。

```sh
dratools get -O ~/Downloads DRR000001
```

ダウンロード中は `curl` または `wget` の進捗が標準エラーに出ます。取得したファイルは `Downloaded<TAB>PATH` と表示します。既存ファイルを再利用した場合は `Skipped<TAB>PATH` と表示します。これらは標準エラーに出ます。最後に `dratools get: N downloaded, M skipped` のサマリを出します。状態とパスは TAB 区切りです。パスだけを取り出すには `cut -f2` を使います。

### 既存ファイルの扱い

DDBJ のメタデータに md5 が含まれることは多くありません。ほとんどの場合、md5 は得られません。以下では、まず md5 が無い場合の動作を示します。

同名のファイルが既にある場合、`get` はサーバにファイルサイズを問い合わせます。それをローカルのファイルサイズと比べます。

- サイズが同じなら、再取得しません。`Skipped` と表示します。
- ローカルのほうが小さいなら、再取得します。途中で中断したファイルが対象です。
- ローカルのほうが大きいなら、エラーになります。別物の可能性があるためです。`--force` で上書きできます。

md5 が得られる場合は、サイズではなく md5 で判定します。既存ファイルの md5 が一致すれば `Skipped` と表示します。ダウンロード後にも md5 を照合します。

### オプション

| オプション | 動作 |
| --- | --- |
| `--force` | 既存ファイルがあっても再取得します。 |
| `--skip-existing` | 同名のファイルがあれば、確認せずスキップします。サーバへの問い合わせを省きます。 |
| `--no-verify` | ダウンロード後の md5 照合を省きます。md5 が無い場合は照合しないので、効果はありません。 |

```sh
dratools get --force -O ~/Downloads DRR000001
dratools get --skip-existing -O ~/Downloads DRR000001
```

`--force` と `--skip-existing` を同時に指定した場合は、`--force` を優先します。

## accession の渡し方

どのコマンドも accession を3つの方法で受け取れます。引数、ファイル、標準入力です。

ファイルから読む場合は `--input` を使います。

```sh
dratools url --input accessions.txt
```

標準入力から読む場合は、accession をパイプで渡します。

```sh
printf 'DRR000001\nDRR000002\n' | dratools url
```

標準入力を明示する場合は `--input -` を指定します。

```sh
printf 'DRR000001\nDRR000002\n' | dratools url --input -
```

## ライブラリとして使う

`dratools` は Ruby のライブラリとしても使えます。

```ruby
require "dratools"

resolver = Dratools::AccessionResolver.new
downloads = resolver.resolve_downloads("DRR000001", file_type: "sra")

downloads.each do |download|
  puts download.url_for_protocol("https")
end
```

接続確認は次のように書きます。

```ruby
downloader = Dratools::DownloadService.new
downloader.probe_download(downloads.first, timeout: 5)
```

ダウンロードは次のように書きます。

```ruby
result = downloader.save_download(downloads.first, outdir: "downloads")
puts result.skipped? ? "skipped: #{result.path}" : "downloaded: #{result.path}"
```

## 対応アクセッション

DDBJ Search の JSON から `sra-run` を辿れる accession を対象にします。

- Run: `DRR`, `ERR`, `SRR`
- Experiment: `DRX`, `ERX`, `SRX`
- Sample: `DRS`, `ERS`, `SRS`
- Study: `DRP`, `ERP`, `SRP`
- Submission: `DRA`, `ERA`, `SRA`
- BioProject: `PRJDA`, `PRJDB`, `PRJEB`, `PRJNA`
- BioSample: `SAMD`, `SAMN`, `SAMEA`, `SAMEG`

## 終了ステータス

- `0`: 成功
- `1`: URL 解決、接続確認、ダウンロード、オプション指定、不明なサブコマンドのいずれかで失敗

複数の accession をまとめて処理する場合を考えます。成功した accession は処理を続けます。失敗した accession はエラーを標準エラーに出します。1 件でも失敗すると、全体の終了ステータスは `1` になります。
