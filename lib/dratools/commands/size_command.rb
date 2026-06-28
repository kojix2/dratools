# frozen_string_literal: true

require 'json'

require_relative '../byte_formatter'
require_relative '../config'
require_relative '../ddbj_record_fields'
require_relative 'base_command'

module Dratools
  module Commands
    # 実ファイルの Content-Length を HEAD で集計する。
    class SizeCommand < BaseCommand
      DEFAULT_SIZE_TIMEOUT_SECONDS = DownloadService::DEFAULT_SIZE_TIMEOUT_SECONDS
      TSV_COLUMNS = %w[accession files size unresolved].freeze

      private

      def command_name
        'size'
      end

      def default_options
        super.merge(
          protocol: DEFAULT_PROTOCOL,
          timeout: DEFAULT_SIZE_TIMEOUT_SECONDS,
          bytes: false,
          json: false,
          per_run: false
        )
      end

      def configure_parser(parser)
        add_protocol_option(parser)
        parser.on('--timeout SEC', Integer,
                  "HEAD/ディレクトリ取得の秒数 (default: #{DEFAULT_SIZE_TIMEOUT_SECONDS})") do |value|
          @options[:timeout] = value
        end
        parser.on('--bytes', 'サイズをバイト数で表示する') { @options[:bytes] = true }
        parser.on('-r', '--per-run', '親 accession を run accession ごとに分けて集計する') do
          @options[:per_run] = true
        end
        parser.on('--json', 'サイズ集計を JSON で表示する') { @options[:json] = true }
      end

      def usage_examples
        [
          "#{Dratools::NAME} size DRR000001",
          "#{Dratools::NAME} size --type fastq PRJNA341783",
          "#{Dratools::NAME} size --per-run DRX000001",
          "#{Dratools::NAME} size --json DRR000001 DRR000002"
        ]
      end

      def validate_options
        super
        validate_protocol
        timeout = @options[:timeout]
        return if timeout.positive?

        raise InvalidOptionError, "invalid --timeout '#{timeout}' (expected: positive integer)"
      end

      def process(accession)
        ddbj_record = fetch_record_for_size(accession)
        downloads = @resolver.resolve_downloads_from_record(
          accession,
          ddbj_record,
          file_type: @options[:file_type]
        )
        if @options[:per_run]
          downloads.group_by(&:run_accession).each do |run_accession, group|
            record_result(run_accession, group)
          end
        else
          record_result(accession, downloads)
        end
      end

      def record_result(label, downloads)
        lengths = downloads.flat_map do |download|
          @downloader.content_lengths(
            download,
            protocol: @options[:protocol],
            timeout: @options[:timeout]
          )
        end
        result = {
          accession: label,
          file_count: lengths.length,
          total_size: lengths.compact.sum,
          unresolved_count: lengths.count(&:nil?)
        }
        results << result
        print_text_result(result) unless @options[:json]
      end

      def finalize
        if @options[:json]
          @stdout.puts JSON.pretty_generate(results)
          return
        end

        return if results.length < 2

        # --per-run の集計行はデータ行と混ぜず標準エラーに出し、stdout を純粋な TSV に保つ。
        print_text_result(total_result, io: @options[:per_run] ? @stderr : @stdout)
      end

      def results
        @results ||= []
      end

      def total_result
        {
          accession: 'total',
          file_count: results.sum { |result| result[:file_count] },
          total_size: results.sum { |result| result[:total_size] },
          unresolved_count: results.sum { |result| result[:unresolved_count] }
        }
      end

      def print_text_result(result, io: @stdout)
        emit_tsv_header(TSV_COLUMNS)
        io.puts [
          result[:accession],
          result[:file_count],
          formatted_size(result),
          result[:unresolved_count]
        ].join("\t")
      end

      def formatted_size(result)
        size = result[:total_size]
        return MISSING_VALUE if size.zero? && result[:unresolved_count].positive?
        return size.to_s if @options[:bytes]

        ByteFormatter.format(size)
      end

      def fetch_record_for_size(accession)
        max_direct_runs = Config.size_max_direct_runs
        validate_direct_run_expansion_count!(accession, max_direct_runs)
        @resolver.fetch_record_for(accession)
      end

      def validate_direct_run_expansion_count!(accession, max_direct_runs)
        return unless max_direct_runs

        direct_run_count = @resolver.direct_run_count_for(accession)
        return if direct_run_count <= max_direct_runs

        raise_direct_run_limit_error(accession, direct_run_count, max_direct_runs)
      end

      def raise_direct_run_limit_error(accession, direct_run_count, max_direct_runs)
        raise InvalidRecordError,
              "#{accession.to_s.upcase} has #{direct_run_count} direct runs; " \
              "size expands at most #{max_direct_runs} direct runs from one parent accession. " \
              "Use `#{Dratools::NAME} runs #{accession}` and pass narrower accessions."
      end
    end
  end
end
