# 開発

## テスト

単体テストは次のコマンドで実行します。

```sh
bundle exec rake test
```

DDBJ へアクセスする統合テストは次のコマンドで実行します。

```sh
DRATOOLS_INTEGRATION=1 bundle exec rake test
```

静的解析は次のコマンドで実行します。

```sh
bundle exec rake rubocop
```

統合テストは `DRR000001` を使います。URL 解決と短時間の接続確認を行います。ファイルを最後までダウンロードしません。

## gem の確認

```sh
gem build dratools.gemspec
gem install ./dratools-*.gem
dratools --help
```

## 方針

- なるべく Ruby の標準ライブラリで実装する
- CLI は薄く保ち、主要な処理はライブラリ側に置く
- ネットワークを使うテストは opt-in にする
- ファイルを最後まで誤って落とすテストは書かない
- CI では RuboCop とテストの両方を実行する
