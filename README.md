# ddbj-get

`ddbj-get` は、DDBJ Search を使って DRA/SRA のダウンロード URL を解決し、DDBJ から `.sra` などを取得するための小さな Ruby Gem です。

```sh
gem install ddbj-get

ddbj-get --print-url DRR000001
ddbj-get --probe DRR000001
ddbj-get -O sra DRR000001
```

標準ライブラリを中心に実装しています。実際のファイル転送には `curl` または `wget` を使います。

## ドキュメント

- [使い方](docs/usage.md)
- [設計メモ](docs/design.md)
- [開発](docs/development.md)

## 注意

ゲノムデータは非常に大きいことがあります。まず `--print-url` または `--probe` で確認してからダウンロードすることをおすすめします。

## ライセンス

MIT
