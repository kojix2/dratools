# frozen_string_literal: true

require 'optparse'

require_relative '../errors'
require_relative '../download_candidate'
require_relative '../accession_resolver'
require_relative '../download_service'
require_relative '../accession_input_collector'

module Dratools
  module Commands
    # サブコマンド共通の土台。オプション解析・accession 収集・例外処理・終了コードを担う。
    class BaseCommand
      SUCCESS_EXIT_STATUS = 0
      FAILURE_EXIT_STATUS = 1

      DEFAULT_FILE_TYPE = AccessionResolver::FILE_TYPE_SRA
      VALID_FILE_TYPES = [
        AccessionResolver::FILE_TYPE_SRA,
        AccessionResolver::FILE_TYPE_FASTQ,
        AccessionResolver::FILE_TYPE_ALL
      ].freeze
      DEFAULT_PROTOCOL = DownloadCandidate::HTTPS_PROTOCOL
      VALID_PROTOCOLS = [DownloadCandidate::HTTPS_PROTOCOL, DownloadCandidate::FTP_PROTOCOL].freeze
      # 値が無いことを表す TSV のプレースホルダ。
      MISSING_VALUE = 'NA'

      def initialize(argv, resolver:, downloader:, stdout:, stderr:, stdin:)
        @argv = argv
        @resolver = resolver
        @downloader = downloader
        @stdout = stdout
        @stderr = stderr
        @stdin = stdin
        @options = default_options
        @failed_count = 0
      end

      def run
        parse_options
        return @halt unless @halt.nil?

        begin
          accessions = collect_accessions
        rescue MissingAccessionError
          @stderr.puts build_option_parser
          return FAILURE_EXIT_STATUS
        end

        accessions.each do |accession|
          process(accession)
        rescue Error => error
          report_error(error.message, accession: accession)
          @failed_count += 1
        end
        finalize
        @failed_count.zero? ? SUCCESS_EXIT_STATUS : FAILURE_EXIT_STATUS
      rescue OptionParser::ParseError, Error => error
        report_error(error.message)
        FAILURE_EXIT_STATUS
      end

      private

      attr_reader :options, :resolver, :downloader, :stdout, :stderr

      # --- サブクラスで上書きするフック -------------------------------------

      # サブコマンド名（バナーやエラー接頭辞に使う）。
      def command_name
        raise NotImplementedError
      end

      # サブクラス固有の既定オプション。
      def default_options
        { file_type: DEFAULT_FILE_TYPE, input: nil }
      end

      # サブクラス固有のオプションを parser に足す。
      def configure_parser(parser); end

      # サブクラス固有の使用例（1 行ずつ）。
      def usage_examples
        []
      end

      # accession 1 件の処理本体。
      def process(accession)
        raise NotImplementedError
      end

      # 全 accession 処理後の後処理（JSON 出力やサマリなど）。
      def finalize; end

      # --- 共通処理 ---------------------------------------------------------

      def parse_options
        parser = build_option_parser
        parser.parse!(@argv)
        return unless @halt.nil?

        validate_options
      end

      def build_option_parser
        OptionParser.new do |parser|
          parser.summary_width = 24
          parser.banner = "Usage: #{Dratools::NAME} #{command_name} [options] [ACCESSION ...]"
          add_common_options(parser)
          configure_parser(parser)
          add_examples(parser)
        end
      end

      def add_common_options(parser)
        file_type_description = "取得対象を指定する。sra, fastq, all (default: #{DEFAULT_FILE_TYPE})"
        parser.on('--type TYPE', file_type_description) do |value|
          @options[:file_type] = value
        end
        parser.on('-i', '--input FILE', 'accession 一覧をファイルまたは標準入力(-)から読む') do |value|
          @options[:input] = value
        end
        parser.on('-h', '--help', 'ヘルプを表示する') do
          @stdout.puts parser
          @halt = SUCCESS_EXIT_STATUS
        end
      end

      def add_protocol_option(parser)
        description = "優先する URL 種別を指定する。https, ftp (default: #{DEFAULT_PROTOCOL})"
        parser.on('--protocol PROTOCOL', description) { |value| @options[:protocol] = value }
      end

      def add_examples(parser)
        examples = usage_examples
        return if examples.empty?

        parser.separator ''
        parser.separator 'Examples:'
        examples.each { |example| parser.separator "  #{example}" }
      end

      def validate_options
        file_type = @options[:file_type]
        return if VALID_FILE_TYPES.include?(file_type)

        raise InvalidOptionError, invalid_message('--type', file_type, VALID_FILE_TYPES)
      end

      def validate_protocol
        protocol = @options[:protocol]
        return if VALID_PROTOCOLS.include?(protocol)

        raise InvalidOptionError, invalid_message('--protocol', protocol, VALID_PROTOCOLS)
      end

      def invalid_message(name, value, expected)
        "invalid #{name} '#{value}' (expected: #{expected.join(', ')})"
      end

      def collect_accessions
        AccessionInputCollector.new(
          argv: @argv,
          input_path: @options[:input],
          stdin: @stdin
        ).collect_accessions
      end

      def resolve_downloads(accession)
        @resolver.resolve_downloads(accession, file_type: @options[:file_type])
      end

      # 列名を `#` 始まりのヘッダ行として一度だけ出力する。
      def emit_tsv_header(columns)
        return if @tsv_header_printed

        @stdout.puts "##{columns.join("\t")}"
        @tsv_header_printed = true
      end

      def report_error(message, accession: nil)
        prefix = "#{Dratools::NAME} #{command_name}"
        prefix = "#{prefix}: #{accession}" if accession
        @stderr.puts "#{prefix}: #{message}"
      end
    end
  end
end
