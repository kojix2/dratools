# 開発

## テスト

通常の単体テスト:

```sh
bundle exec rake test
```

実際に DDBJ へアクセスする統合テスト:

```sh
DDBJ_GET_INTEGRATION=1 bundle exec rake test
```

統合テストでは `DRR000001` を使って URL 解決と短時間の `--probe` 相当の確認を行います。巨大ファイルを最後までダウンロードしません。

## gem の確認

```sh
gem build ddbj-get.gemspec
gem install ./ddbj-get-*.gem
ddbj-get --help
```

## 方針

- なるべく Ruby 標準ライブラリで実装する
- CLI は薄く保ち、主要処理はライブラリ側に置く
- ネットワークを使うテストは明示的に opt-in にする
- 巨大ファイルを誤って落とすテストは書かない
