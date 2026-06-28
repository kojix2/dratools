# dratools

[![CI](https://github.com/kojix2/dratools/actions/workflows/ci.yml/badge.svg)](https://github.com/kojix2/dratools/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/dratools.svg)](https://badge.fury.io/rb/dratools)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Fdratools%2Flines)](https://tokei.kojix2.net/github/kojix2/dratools)
[![DOI](https://zenodo.org/badge/1281844096.svg)](https://doi.org/10.5281/zenodo.20967539)

[dratools](https://github.com/kojix2/dratools) は、日本国内の [DDBJ](https://www.ddbj.nig.ac.jp) からゲノムデータをダウンロードするためのツールです。

[DDBJ Search](https://ddbj.nig.ac.jp/search/) を使って [DRA/SRA](https://en.wikipedia.org/wiki/Sequence_Read_Archive) のダウンロード URL を解決します。日本国内のサーバーから `.sra` を取得します。

dratools は非公式のツールです。DDBJ や国立遺伝学研究所が提供する公式のツールではありません。

## インストール

必要なものは次のとおりです。

- [ruby](https://www.ruby-lang.org/) 3.0 以上
- [curl](https://curl.se/) または [wget](https://www.gnu.org/software/wget/)

Rubyのgemとしてインストールできます。

```sh
gem install dratools
```

## 使い方

`dratools` はサブコマンド方式です。`dratools <command> --help` で各コマンドのオプションを確認できます。

| コマンド | 役割 |
| --- | --- |
| `url`   | ダウンロード URL を表示する（`--tsv` で TAB 区切り列、`--json` で JSON 出力） |
| `get`   | ファイルをダウンロードする |
| `probe` | 短時間の接続確認だけを行う |
| `tree`  | accession から run へ辿る探索ツリーを表示する |
| `meta`  | レコードのメタ情報を表示する（`--json` で生 JSON） |
| `runs`  | run accession の一覧を出力する |
| `size`  | ダウンロード合計サイズを集計する（`--per-run` で run ごとに分割） |

コマンド名は基本的に単数形ですが、一覧を返す `runs` だけ複数形です。打ち間違い対策として `run`/`urls`/`sizes`/`trees` の別名も受け付けます。

```sh
# まずダウンロード URL を確認する
dratools url DRR000001

# BioProject などから run へ辿る経路を確認する
dratools tree PRJNA341783

# レコードの概要を確認する
dratools meta DRR000001

# BioProject を run accession 一覧に展開する
dratools runs PRJNA341783

# ダウンロード前に合計サイズを見積もる
dratools size PRJNA341783

# カレントディレクトリにダウンロードする
dratools get DRR000001

# 保存先ディレクトリを指定してダウンロードする
dratools get -O ~/Downloads DRR000001
```

複数の accession もまとめて渡せます。

```sh
# 引数で複数指定
dratools get -O ~/Downloads DRR000001 DRR000002

# ファイルから渡す
dratools get --input list.txt -O ~/Downloads

# 標準入力から渡す
printf 'DRR000001\nDRR000002\n' | dratools get -O ~/Downloads
```

## そのほかのコマンド例

```sh
dratools probe DRR000001                          # URL の到達性だけ確認する
dratools url --json DRR000001                     # URL 情報を JSON で表示する
dratools url --tsv DRR000001                      # run/type/url/size/md5 を TAB 区切りで
dratools meta --json DRR000001                    # entry JSON を表示する
dratools runs PRJNA341783 | dratools get -O ~/Downloads # run 一覧をダウンロードへ渡す
dratools size --bytes PRJNA341783                 # 合計サイズをバイト数で表示する
dratools size --per-run DRX000001                 # 親 accession を run ごとに集計する
dratools get --skip-existing -O ~/Downloads DRR000001  # 既存ファイルは触らない
```

詳しくは [使い方](docs/usage.md) をご覧ください。親 accession を扱うときの設定は [環境変数](docs/environment.md) にまとめています。

実際のファイル転送には通常 `curl` または `wget` を使います。`aria2c` も環境変数で明示した場合だけ使えます。ダウンロード中は進捗表示を端末にそのまま流します。同名のファイルが既にある場合は、サーバのファイルサイズと比べて再取得の要否を判断します。md5 が得られる場合は md5 で照合します。

ツールは全てコーディングエージェントによって実装されました。

## ドキュメント

- [使い方](docs/usage.md)
- [環境変数](docs/environment.md)
- [設計メモ](docs/design.md)
- [開発](docs/development.md)

## お役立ちノート

海外のサーバーからゲノムデータをダウンロードするのは大変です。日本国内のサーバーを使うと作業が楽になります。

手間をかけずにダウンロードする方法として、NAS を使う方法があります。まず `dratools url` で URL の一覧を出します。次に NAS の付属ソフトの GUI 画面に、その URL をまとめて貼り付けます。あとは放置します。ダウンロードは自動で進みます。

## 開発

本ツールの開発は日本語で行います。
バグ報告を issue にお寄せください。
プルリクエストは高い確率でマージされます。
バグレポートやプルリクエストは、日本語でなくても構いません。

## ライセンス

MIT
