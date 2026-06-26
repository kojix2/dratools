# frozen_string_literal: true

require_relative 'base_command'

module Dratools
  module Commands
    # 短時間の接続確認だけを行う（完全なダウンロードはしない）。
    class ProbeCommand < BaseCommand
      DEFAULT_PROBE_TIMEOUT_SECONDS = DownloadService::DEFAULT_PROBE_TIMEOUT_SECONDS
      PROBE_SUCCESS_PREFIX = 'OK'

      private

      def command_name
        'probe'
      end

      def default_options
        super.merge(protocol: DEFAULT_PROTOCOL, timeout: DEFAULT_PROBE_TIMEOUT_SECONDS)
      end

      def configure_parser(parser)
        add_protocol_option(parser)
        parser.on('--timeout SEC', Integer,
                  "接続確認の秒数 (default: #{DEFAULT_PROBE_TIMEOUT_SECONDS})") do |value|
          @options[:timeout] = value
        end
      end

      def usage_examples
        [
          "#{Dratools::NAME} probe DRR000001",
          "#{Dratools::NAME} probe --timeout 10 DRR000001"
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
        protocol = @options[:protocol]
        resolve_downloads(accession).each do |download|
          @downloader.probe_download(download, protocol: protocol, timeout: @options[:timeout])
          @stdout.puts "#{PROBE_SUCCESS_PREFIX}\t#{download.url_for_protocol(protocol)}"
        end
      end
    end
  end
end
