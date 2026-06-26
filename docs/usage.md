# 使い方

## インストール

```sh
gem install ddbj-get
```

開発中のリポジトリから使う場合:

```sh
bundle install
bundle exec ruby -Ilib bin/ddbj-get --help
```

## 基本

`.sra` の URL を表示します。

```sh
ddbj-get --print-url DRR000001
```

短時間の接続確認だけを行います。巨大ファイルを最後まで落としません。

```sh
ddbj-get --probe --timeout 5 DRR000001
```

ダウンロードします。

```sh
ddbj-get -O sra DRR000001
```

FTP URL を使う場合:

```sh
ddbj-get --protocol ftp --print-url DRR000001
```

FASTQ を探す場合:

```sh
ddbj-get --file-type fastq --print-url DRR000001
```

JSON で表示する場合:

```sh
ddbj-get --json DRR000001
```

## ライブラリとして使う

```ruby
require "ddbj/get"

resolver = Ddbj::Get::Resolver.new
downloads = resolver.resolve("DRR000001", file_type: "sra")

downloads.each do |download|
  puts download.preferred_url("https")
end
```

短時間の接続確認:

```ruby
downloader = Ddbj::Get::Downloader.new
downloader.probe(downloads.first, timeout: 5)
```

## 対応アクセッション

最初の版では、DDBJ Search の JSON から `sra-run` をたどれるものを対象にします。

- Run: `DRR`, `ERR`, `SRR`
- Experiment: `DRX`, `ERX`, `SRX`
- Sample: `DRS`, `ERS`, `SRS`
- Study: `DRP`, `ERP`, `SRP`
- Submission: `DRA`, `ERA`, `SRA`
- BioProject: `PRJDB`, `PRJEB`, `PRJNA`
- BioSample: `SAMD`, `SAMN`, `SAMEA`

## 終了ステータス

- `0`: 成功
- `1`: URL解決、接続確認、ダウンロード、オプション指定のいずれかで失敗
