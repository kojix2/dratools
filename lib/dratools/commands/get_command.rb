# frozen_string_literal: true

require_relative 'base_command'

module Dratools
  module Commands
    # 実際にファイルをダウンロードする。
    class GetCommand < BaseCommand
      DEFAULT_OUTPUT_DIRECTORY = DownloadService::DEFAULT_OUTPUT_DIRECTORY
      DOWNLOAD_SUCCESS_PREFIX = 'Downloaded'
      DOWNLOAD_SKIPPED_PREFIX = 'Skipped'

      private

      def command_name
        'get'
      end

      def default_options
        super.merge(
          protocol: DEFAULT_PROTOCOL,
          outdir: DEFAULT_OUTPUT_DIRECTORY,
          verify: true,
          force: false,
          skip_existing: false
        )
      end

      def configure_parser(parser)
        parser.on('-O', '--outdir DIR',
                  "ダウンロード先ディレクトリ (default: #{DEFAULT_OUTPUT_DIRECTORY})") do |value|
          @options[:outdir] = value
        end
        add_protocol_option(parser)
        parser.on('--no-verify', 'md5 がある場合のダウンロード後検証を省略する') { @options[:verify] = false }
        parser.on('--force', '既存ファイルがあっても再取得する') { @options[:force] = true }
        parser.on('--skip-existing', '既存ファイルがあれば検証せず再取得しない') { @options[:skip_existing] = true }
      end

      def usage_examples
        [
          "#{Dratools::NAME} get DRR000001",
          "#{Dratools::NAME} get -O ~/Downloads DRR000001 DRR000002",
          "#{Dratools::NAME} get --skip-existing -O ~/Downloads DRR000001"
        ]
      end

      def validate_options
        super
        validate_protocol
      end

      def process(accession)
        resolve_downloads(accession).each do |download|
          save_one_download(accession, download)
        end
      end

      def finalize
        parts = ["#{@downloaded_count.to_i} downloaded", "#{@skipped_count.to_i} skipped"]
        parts << "#{@failed_count} failed" if @failed_count.positive?
        @stderr.puts "#{Dratools::NAME} #{command_name}: #{parts.join(', ')}"
      end

      def save_one_download(accession, download)
        result = @downloader.save_download(
          download,
          outdir: @options[:outdir],
          protocol: @options[:protocol],
          verify: @options[:verify],
          force: @options[:force],
          skip_existing: @options[:skip_existing]
        )
        if result.skipped?
          @skipped_count = @skipped_count.to_i + 1
          @stderr.puts "#{DOWNLOAD_SKIPPED_PREFIX}\t#{result.path}"
        else
          @downloaded_count = @downloaded_count.to_i + 1
          @stderr.puts "#{DOWNLOAD_SUCCESS_PREFIX}\t#{result.path}"
        end
      rescue Error => error
        report_error(error.message, accession: accession)
        @failed_count += 1
      end
    end
  end
end
