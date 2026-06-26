# 設計メモ

## 目的

既存の SRA 系ツールは、DDBJ accession を受け付けても、実際には ENA API や NCBI SRA Toolkit に寄せるものが多いです。

`ddbj-get` は、DDBJ Search の情報を使い、DDBJ が公開している DRA ファイル URL を取得することに絞ります。

## データ取得の流れ

```text
accession
  -> DDBJ Search resource JSON
  -> sra-run record
  -> downloadUrl
  -> https / ftp URL
```

## ダウンロード確認

ゲノムデータは大きいため、`--probe` は完全なダウンロードを行いません。

- `curl` がある場合: `--range 0-0` と `--max-time` を使う
- `wget` がある場合: `--spider` と `--timeout` を使う

これは「URL が動きそうか」を短時間で確認するためのものです。完全な整合性確認ではありません。

## 標準ライブラリ中心

Ruby 側の依存は増やさず、以下を使います。

- `net/http`
- `json`
- `optparse`
- `open3`
- `fileutils`
- `minitest`

実ファイル転送だけは、既存環境にある `curl` または `wget` に任せます。

## 今後の候補

- DDBJ Search API の追加形式に対応
- `ascp` 対応
- `vdb-validate` 呼び出し
- DRA 以外の DDBJ Search レコードを扱う `ddbj-search` サブコマンド
- `getentry` を扱う別コマンド
