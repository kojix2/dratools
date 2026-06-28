# frozen_string_literal: true

require_relative 'version'
require_relative 'accession_resolver'
require_relative 'download_service'
require_relative 'commands/url_command'
require_relative 'commands/get_command'
require_relative 'commands/probe_command'
require_relative 'commands/tree_command'
require_relative 'commands/meta_command'
require_relative 'commands/runs_command'
require_relative 'commands/size_command'

module Dratools
  # サブコマンドを振り分ける CLI の入口。
  class CommandLineInterface
    COMMAND_NAME = Dratools::NAME
    SUCCESS_EXIT_STATUS = 0
    FAILURE_EXIT_STATUS = 1

    SUBCOMMANDS = {
      'url' => Commands::UrlCommand,
      'get' => Commands::GetCommand,
      'probe' => Commands::ProbeCommand,
      'tree' => Commands::TreeCommand,
      'meta' => Commands::MetaCommand,
      'runs' => Commands::RunsCommand,
      'size' => Commands::SizeCommand
    }.freeze

    # 単複の打ち間違いを救う別名。左を打っても右の正規コマンドが動く。
    # ヘルプやエラー・バナーには常に正規名（右）を表示する。
    SUBCOMMAND_ALIASES = {
      'run' => 'runs',
      'urls' => 'url',
      'sizes' => 'size',
      'trees' => 'tree'
    }.freeze

    HELP_FLAGS = ['-h', '--help', 'help'].freeze
    VERSION_FLAGS = ['-v', '--version', 'version'].freeze

    SUBCOMMAND_SUMMARIES = {
      'url' => 'ダウンロード URL を表示する (--json で JSON)',
      'get' => 'ファイルをダウンロードする',
      'probe' => '短時間の接続確認だけ行う',
      'tree' => '探索ツリーを表示する',
      'meta' => 'レコードのメタ情報を表示する (--json で生 JSON)',
      'runs' => 'run accession の一覧を出力する',
      'size' => 'ダウンロード合計サイズを集計する'
    }.freeze

    USAGE_EXAMPLES = [
      "#{COMMAND_NAME} url DRR000001",
      "#{COMMAND_NAME} meta DRR000001",
      "#{COMMAND_NAME} runs PRJNA341783",
      "#{COMMAND_NAME} size PRJNA341783",
      "#{COMMAND_NAME} get -O ~/Downloads DRR000001",
      "#{COMMAND_NAME} tree PRJNA341783",
      "#{COMMAND_NAME} url --input accessions.txt",
      "printf 'DRR000001\\nDRR000002\\n' | #{COMMAND_NAME} url"
    ].freeze

    def self.start(argv)
      new(argv).run
    end

    def initialize(
      argv,
      resolver: AccessionResolver.new,
      downloader: DownloadService.new,
      stdout: $stdout,
      stderr: $stderr,
      stdin: $stdin
    )
      @argv = argv
      @resolver = resolver
      @downloader = downloader
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
    end

    def run
      name = @argv.first

      if name.nil?
        print_help(@stderr)
        return FAILURE_EXIT_STATUS
      end
      if HELP_FLAGS.include?(name)
        print_help(@stdout)
        return SUCCESS_EXIT_STATUS
      end
      if VERSION_FLAGS.include?(name)
        @stdout.puts VERSION
        return SUCCESS_EXIT_STATUS
      end

      command_class = SUBCOMMANDS[name] || SUBCOMMANDS[SUBCOMMAND_ALIASES[name]]
      unless command_class
        expected = SUBCOMMANDS.keys.join(', ')
        @stderr.puts "#{COMMAND_NAME}: unknown command '#{name}' (expected: #{expected})"
        return FAILURE_EXIT_STATUS
      end

      command_class.new(
        @argv.drop(1),
        resolver: @resolver,
        downloader: @downloader,
        stdout: @stdout,
        stderr: @stderr,
        stdin: @stdin
      ).run
    end

    private

    def print_help(stream)
      stream.puts "Usage: #{COMMAND_NAME} <command> [options] [ACCESSION ...]"
      stream.puts ''
      stream.puts 'Commands:'
      SUBCOMMAND_SUMMARIES.each do |name, summary|
        stream.puts format('  %-7<name>s %<summary>s', name: name, summary: summary)
      end
      stream.puts ''
      stream.puts "各コマンドのオプションは '#{COMMAND_NAME} <command> --help' で確認できます。"
      stream.puts ''
      stream.puts 'Examples:'
      USAGE_EXAMPLES.each { |example| stream.puts "  #{example}" }
    end
  end
end
