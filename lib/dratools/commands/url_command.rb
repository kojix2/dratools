# frozen_string_literal: true

require 'json'

require_relative '../config'
require_relative '../ddbj_record_fields'
require_relative 'base_command'

module Dratools
  module Commands
    # ダウンロード URL を表示する（テキストまたは JSON）。
    class UrlCommand < BaseCommand
      TSV_COLUMNS = %w[run_accession type url size md5].freeze

      private

      def command_name
        'url'
      end

      def default_options
        super.merge(protocol: DEFAULT_PROTOCOL, json: false, tsv: false)
      end

      def configure_parser(parser)
        add_protocol_option(parser)
        parser.on('--tsv', 'run_accession, type, url, size, md5 を TAB 区切りで表示する') do
          @options[:tsv] = true
        end
        parser.on('--json', 'URL 情報を JSON で表示する') { @options[:json] = true }
      end

      def usage_examples
        [
          "#{Dratools::NAME} url DRR000001",
          "#{Dratools::NAME} url --protocol ftp DRR000001",
          "#{Dratools::NAME} url --tsv DRR000001 | grep -v '^#' | cut -f3",
          "#{Dratools::NAME} url --json DRR000001 DRR000002"
        ]
      end

      def validate_options
        super
        validate_protocol
      end

      def process(accession)
        ddbj_record = fetch_record_for_url(accession)
        downloads = @resolver.resolve_downloads_from_record(
          accession,
          ddbj_record,
          file_type: @options[:file_type]
        )
        if @options[:json]
          json_buffer.concat(downloads.map { |download| download_to_hash(download) })
        elsif @options[:tsv]
          emit_tsv_header(TSV_COLUMNS)
          downloads.each { |download| @stdout.puts tsv_row(download) }
        else
          downloads.each { |download| @stdout.puts download.url_for_protocol(@options[:protocol]) }
        end
      end

      def finalize
        return unless @options[:json]

        @stdout.puts JSON.pretty_generate(json_buffer)
      end

      def json_buffer
        @json_buffer ||= []
      end

      def fetch_record_for_url(accession)
        max_direct_runs = Config.url_max_direct_runs
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
              "url expands at most #{max_direct_runs} direct runs from one parent accession. " \
              "Use `#{Dratools::NAME} runs #{accession}` and pass narrower accessions, " \
              "or set #{Config::URL_MAX_DIRECT_RUNS_ENV}=unlimited."
      end

      def tsv_row(download)
        [
          download.run_accession,
          download.type,
          download.url_for_protocol(@options[:protocol]),
          download.size || MISSING_VALUE,
          download.md5 || MISSING_VALUE
        ].join("\t")
      end

      def download_to_hash(download)
        {
          run_accession: download.run_accession,
          type: download.type,
          url: download.url,
          ftp_url: download.ftp_url,
          size: download.size,
          md5: download.md5
        }
      end
    end
  end
end
