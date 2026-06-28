# 設計メモ

## 目的

SRA 系のツールには、DDBJ の accession を受け付けるものがあります。しかし内部では ENA API や NCBI SRA Toolkit を使うことが多いです。

`dratools` は DDBJ Search の情報だけを使います。DDBJ が公開する DRA ファイルの URL を取得します。用途はこれに絞ります。

## データ取得の流れ

accession から URL までの流れは次のとおりです。

```text
accession
  -> DDBJ Search resource JSON
  -> sra-run record
  -> downloadUrl
  -> https / ftp URL
```

## ダウンロード確認

ゲノムデータはサイズが大きいです。`probe` は完全なダウンロードを行いません。

- `curl` がある場合: `--range 0-0` と `--max-time` を使う
- `wget` がある場合: `--spider` と `--timeout` を使う
- `aria2c` がある場合: `--dry-run=true` と `--timeout` を使う

これは URL が使えるかどうかを短時間で確認するためです。完全な整合性の確認ではありません。

## サイズ確認

`size` は resource JSON のサイズ情報を使いません。実レコードにはサイズや md5 が含まれないことが多いためです。代わりに、解決した URL に HTTP `HEAD` を送ります。`Content-Length` を合計します。

FASTQ はディレクトリ URL で返ることがあります。その場合はディレクトリ一覧を取得します。`*.fastq*` のリンクを取り出します。各ファイルに `HEAD` を送ります。取得できないものは失敗にしません。`unresolved` として数えます。

`--protocol ftp` を指定しても、候補に `ftpUrl` が無いことがあります。その場合は URL 選択ルールに従って HTTPS URL を使います。この場合も `size` は HTTP `HEAD` で容量を取得します。

## 実ダウンロード

実ダウンロードでは総時間の上限を設けません。数十 GB のファイルでは長時間かかるためです。代わりに、接続のタイムアウトと失速検知を `curl` / `wget` / `aria2c` に渡します。

- `curl`: `--connect-timeout`, `--speed-limit`, `--speed-time`, `--retry`
- `wget`: `--connect-timeout`, `--read-timeout`, `--tries`, `--waitretry`
- `aria2c`: `--connect-timeout`, `--timeout`, `--lowest-speed-limit`, `--max-tries`, `--retry-wait`

`aria2c` は分割ダウンロードができますが、既定では `--split=1` と `--max-connection-per-server=1` で単一接続にします。公共アーカイブへの負荷を既定で増やさないためです。

`DRATOOLS_DOWNLOAD_RETRY_COUNT` はリトライ回数として扱います。`curl --retry` はリトライ回数ですが、`wget --tries` と `aria2c --max-tries` は総試行回数なので、外部コマンドには `DRATOOLS_DOWNLOAD_RETRY_COUNT + 1` を渡します。

ダウンロードは `system(*command)` で実行します。`Open3.capture3` は使いません。外部コマンドの進捗を端末にそのまま表示するためです。失敗した場合は、コマンド行と終了ステータスを `CommandError` にします。

## チェックサムと既存ファイル

md5 が得られる候補では、ダウンロード後に `Digest::MD5.file` で照合します。これはストリーム処理です。

既存ファイルがある場合は、次の順で扱います。

1. `--force` があれば既存ファイルを使わず再取得する
2. `--skip-existing` があれば md5 を見ずに既存ファイルを使う
3. md5 があり、既存ファイルの md5 が一致すれば再取得せず `Skipped` にする
4. それ以外は `curl --continue-at -`, `wget --continue`, `aria2c --continue=true` でレジュームを試みる

md5 が無い候補では、既定では既存ファイルをスキップしません。SRA ファイルとしての検証は dratools の既定動作には含めません。

## 標準ライブラリ中心

Ruby 側の依存は増やしません。次の標準ライブラリを使います。

- `net/http`
- `json`
- `optparse`
- `open3`
- `fileutils`
- `digest/md5`
- `minitest`

実ファイルの転送だけは外部コマンドに任せます。自動選択では環境にある `curl` または `wget` を使います。`aria2c` は `DRATOOLS_DOWNLOAD_COMMAND=aria2c` で明示指定された場合だけ使います。

## 今後の候補

- DDBJ Search API の追加形式に対応
- `ascp` 対応
- `vdb-validate` 呼び出し
- DRA 以外の DDBJ Search レコードを扱う `search` サブコマンド
- `getentry` を扱うサブコマンド
