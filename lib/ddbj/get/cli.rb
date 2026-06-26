# frozen_string_literal: true

require "json"
require "optparse"

require_relative "downloader"
require_relative "resolver"
require_relative "version"

module Ddbj
  module Get
    class CLI
      def self.start(argv)
        new(argv).run
      end

      def initialize(argv)
        @argv = argv
        @options = {
          file_type: "sra",
          protocol: "https",
          outdir: ".",
          timeout: 5,
          mode: :download
        }
      end

      def run
        accessions = parse_options
        resolver = Resolver.new
        downloader = Downloader.new
        downloads = accessions.flat_map { |acc| resolver.resolve(acc, file_type: @options[:file_type]) }

        case @options[:mode]
        when :json
          puts JSON.pretty_generate(downloads.map { |d| download_hash(d) })
        when :print_url
          downloads.each { |d| puts d.preferred_url(@options[:protocol]) }
        when :probe
          downloads.each do |d|
            downloader.probe(d, protocol: @options[:protocol], timeout: @options[:timeout])
            warn "OK #{d.preferred_url(@options[:protocol])}"
          end
        else
          downloads.each do |d|
            path = downloader.download(d, outdir: @options[:outdir], protocol: @options[:protocol])
            warn "Downloaded #{path}"
          end
        end

        0
      rescue Error, OptionParser::ParseError => e
        warn "ddbj-get: #{e.message}"
        1
      end

      private

      def parse_options
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: ddbj-get [options] ACCESSION..."
          opts.on("--file-type TYPE", "取得対象: sra, fastq, all (default: sra)") { |v| @options[:file_type] = v }
          opts.on("--protocol PROTOCOL", "URL種別: https, ftp (default: https)") { |v| @options[:protocol] = v }
          opts.on("-O", "--outdir DIR", "出力ディレクトリ") { |v| @options[:outdir] = v }
          opts.on("--print-url", "URLだけを表示") { @options[:mode] = :print_url }
          opts.on("--json", "URL情報をJSONで表示") { @options[:mode] = :json }
          opts.on("--probe", "短時間の接続確認だけ行う") { @options[:mode] = :probe }
          opts.on("--timeout SEC", Integer, "probeの秒数 (default: 5)") { |v| @options[:timeout] = v }
          opts.on("-v", "--version", "バージョン表示") do
            puts VERSION
            exit 0
          end
          opts.on("-h", "--help", "ヘルプ表示") do
            puts opts
            exit 0
          end
        end
        parser.parse!(@argv)
        validate_options
        raise OptionParser::MissingArgument, "ACCESSION" if @argv.empty?

        @argv
      end

      def validate_options
        raise OptionParser::InvalidArgument, "--file-type" unless %w[sra fastq all].include?(@options[:file_type])
        raise OptionParser::InvalidArgument, "--protocol" unless %w[https ftp].include?(@options[:protocol])
        raise OptionParser::InvalidArgument, "--timeout" unless @options[:timeout].positive?
      end

      def download_hash(download)
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
