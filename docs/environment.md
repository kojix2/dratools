# 環境変数

`dratools` は通常、コマンドラインオプションだけで使えます。BioProject や Study が大きい場合は、環境変数で上限を調整できます。

値には正の整数を指定します。`unlimited` を指定すると、その上限を無効にします。誤った値を指定すると、エラーで終了します。

| 環境変数 | 既定値 | 役割 |
| --- | ---: | --- |
| `DRATOOLS_MAX_RECURSIVE_NON_RUN_XREFS` | `500` | `runs` などが direct run を持たない親レコードから experiment/sample/study などの非 run レコードを再帰的に辿る最大件数 |
| `DRATOOLS_TREE_MAX_DIRECT_RUNS` | `200` | `tree` が direct run レコードを個別取得して URL まで展開する最大 run 件数。超えた場合は件数だけを要約表示 |
| `DRATOOLS_URL_MAX_DIRECT_RUNS` | `200` | `url` が 1 つの親 accession から direct run を暗黙展開して URL を解決する最大 run 件数 |
| `DRATOOLS_SIZE_MAX_DIRECT_RUNS` | `200` | `size` が 1 つの親 accession から direct run を暗黙展開して HEAD する最大 run 件数 |

`unlimited` が使えるのは、上の 4 つの上限設定だけです。

## ダウンロード開始と失速検知

`get` は大きいファイルを扱います。このため、総ダウンロード時間の上限を設けません。代わりに、接続タイムアウト、失速検知、リトライの設定を `curl` / `wget` / `aria2c` に渡します。

| 環境変数 | 既定値 | 役割 |
| --- | ---: | --- |
| `DRATOOLS_DOWNLOAD_CONNECT_TIMEOUT` | `30` | 接続確立のタイムアウト秒数 |
| `DRATOOLS_DOWNLOAD_STALL_TIMEOUT` | `60` | この秒数のあいだ転送速度が閾値を下回ると失速扱いにする |
| `DRATOOLS_DOWNLOAD_STALL_SPEED` | `1024` | `curl` / `aria2c` の失速判定に使う最低転送速度。単位は bytes/sec |
| `DRATOOLS_DOWNLOAD_RETRY_COUNT` | `3` | ダウンロード失敗時のリトライ回数。`0` はリトライなし |
| `DRATOOLS_DOWNLOAD_RETRY_WAIT` | `5` | `wget` / `aria2c` のリトライ待ち秒数 |
| `DRATOOLS_DOWNLOAD_COMMAND` | 自動 | 実ダウンロードと `probe` に使う外部コマンド。`curl`, `wget`, `aria2c` のいずれか |

`DRATOOLS_DOWNLOAD_COMMAND` を指定しない場合は、`curl`, `wget` の順で PATH にあるものを使います。`aria2c` は自動探索しません。`aria2c` を使う場合は `DRATOOLS_DOWNLOAD_COMMAND=aria2c` を指定してください。指定した場合はそのコマンドだけを使います。見つからない場合は、別のコマンドへ自動では切り替えません。

`DRATOOLS_DOWNLOAD_RETRY_COUNT` は、初回の試行を含まない「リトライ回数」です。`curl` にはそのまま渡します。`wget` と `aria2c` は総試行回数を受け取るため、内部で `リトライ回数 + 1` に変換します。

## 例

`tree` の direct run 展開の既定値は 200 件です。
500 件に上げる例:

```sh
DRATOOLS_TREE_MAX_DIRECT_RUNS=500 dratools tree PRJDB12740
```

この値を小さくすると、展開しない direct run は要約だけを表示します。

`size` の direct run 暗黙展開の既定値は 200 件です。
500 件に上げる例:

```sh
DRATOOLS_SIZE_MAX_DIRECT_RUNS=500 dratools size PRJDB12740
```

`url` の direct run 暗黙展開の既定値は 200 件です。
500 件に上げる例:

```sh
DRATOOLS_URL_MAX_DIRECT_RUNS=500 dratools url --tsv PRJDB12740
```

再帰的な非 run 展開の上限を外す:

```sh
DRATOOLS_MAX_RECURSIVE_NON_RUN_XREFS=unlimited dratools runs ERP005466
```

ダウンロードの開始を検証するため、接続と失速の設定を小さくする:

```sh
DRATOOLS_DOWNLOAD_CONNECT_TIMEOUT=2 \
DRATOOLS_DOWNLOAD_STALL_TIMEOUT=2 \
DRATOOLS_DOWNLOAD_RETRY_COUNT=0 \
dratools get --no-verify -O ~/Downloads DRR000001
```

`wget` を明示してダウンロードする:

```sh
DRATOOLS_DOWNLOAD_COMMAND=wget dratools get -O ~/Downloads DRR000001
```

`aria2c` を明示してダウンロードする:

```sh
DRATOOLS_DOWNLOAD_COMMAND=aria2c dratools get -O ~/Downloads DRR000001
```

## 注意

これらは上級の設定です。上限を大きくすると、DDBJ Search API へのリクエスト数が増えます。`size` の HTTP `HEAD` の回数も増えます。

`DRATOOLS_URL_MAX_DIRECT_RUNS` と `DRATOOLS_SIZE_MAX_DIRECT_RUNS` は direct run 数の上限です。experiment や sample や study を経由して見つかる run の総数は制限しません。`*_MAX_DIRECT_RUNS=unlimited` だけでは `DRATOOLS_MAX_RECURSIVE_NON_RUN_XREFS` の上限は外れません。

まず `meta` や `tree` で構造を確認してください。必要なら `runs` で accession を絞ってください。その後で重い操作を実行してください。

ダウンロード用の設定を小さくしすぎる場合を考えます。正常なサーバーでも、開始前や転送中に失敗します。短い値は動作検証やネットワーク問題の切り分けに使ってください。通常のダウンロードでは既定値を使ってください。
