# frozen_string_literal: true

require 'cgi/escape'
require 'fileutils'
require 'net/http'
require 'timeout'
require 'uri'

require_relative 'download_candidate'
require_relative 'external_command_runner'
require_relative 'checksum_verifier'
require_relative 'errors'
require_relative 'version'

module Dratools
  # 解決済みダウンロードの取得、probe、md5 検証、既存ファイル判定をまとめて扱う。
  class DownloadService
    DownloadResult = Struct.new(:path, :skipped, keyword_init: true) do
      def skipped?
        skipped
      end

      def to_s
        path
      end
    end

    DEFAULT_OUTPUT_DIRECTORY = '.'
    DEFAULT_PROTOCOL = DownloadCandidate::HTTPS_PROTOCOL
    DEFAULT_PROBE_TIMEOUT_SECONDS = 5
    DEFAULT_SIZE_TIMEOUT_SECONDS = 10
    DEFAULT_REDIRECT_LIMIT = 5
    HTTP_LOCATION_HEADER = 'location'
    HTTPS_SCHEME = 'https'
    USER_AGENT_HEADER = 'User-Agent'
    FASTQ_HREF_PATTERN = /href=(?<quote>["'])(?<href>[^"']*\.fastq[^"']*)\k<quote>/i

    def initialize(runner: ExternalCommandRunner.new, checksum_verifier: ChecksumVerifier.new)
      @runner = runner
      @checksum_verifier = checksum_verifier
    end

    def probe_download(download, protocol: DEFAULT_PROTOCOL, timeout: DEFAULT_PROBE_TIMEOUT_SECONDS)
      @runner.probe_url(download.url_for_protocol(protocol), timeout: timeout)
    end

    def content_lengths(download, protocol: DEFAULT_PROTOCOL, timeout: DEFAULT_SIZE_TIMEOUT_SECONDS)
      download_url = download.url_for_protocol(protocol)
      return [nil] unless http_url?(download_url)

      if download.directory_url_for_protocol?(protocol)
        file_urls = directory_file_urls(download_url, timeout: timeout)
        return [nil] if file_urls.empty?

        return file_urls.map { |file_url| safe_head_content_length(file_url, timeout: timeout) }
      end

      [safe_head_content_length(download_url, timeout: timeout)]
    rescue Error
      [nil]
    end

    def save_download(
      download,
      outdir: DEFAULT_OUTPUT_DIRECTORY,
      protocol: DEFAULT_PROTOCOL,
      verify: true,
      force: false,
      skip_existing: false
    )
      FileUtils.mkdir_p(outdir)
      download_url = download.url_for_protocol(protocol)
      if download.directory_url_for_protocol?(protocol)
        raise InvalidRecordError, "download URL points to a directory: #{download_url}"
      end

      output_path = File.join(outdir, download.filename_for_protocol(protocol))
      FileUtils.rm_f(output_path) if force && File.file?(output_path)
      if should_skip_existing?(
        output_path,
        download,
        download_url: download_url,
        skip_existing: skip_existing
      )
        return DownloadResult.new(path: output_path, skipped: true)
      end

      @runner.download_url(download_url, output_path)
      if verify && checksum_available?(download)
        @checksum_verifier.verify_md5!(output_path, download.md5)
      end
      DownloadResult.new(path: output_path, skipped: false)
    end

    private

    def should_skip_existing?(output_path, download, download_url:, skip_existing:)
      return false unless File.file?(output_path)
      return true if skip_existing
      if checksum_available?(download)
        return @checksum_verifier.md5_matches?(output_path, download.md5)
      end

      existing_file_complete?(output_path, download_url)
    end

    def existing_file_complete?(output_path, download_url)
      remote_size = safe_head_content_length(download_url, timeout: DEFAULT_SIZE_TIMEOUT_SECONDS)
      return false unless remote_size

      local_size = File.size(output_path)
      return true if local_size == remote_size
      return false if local_size < remote_size

      raise InvalidRecordError,
            "existing file is larger than remote file: #{output_path} " \
            "(local=#{local_size}, remote=#{remote_size}); use --force to re-download"
    end

    def checksum_available?(download)
      !download.md5.to_s.strip.empty?
    end

    def http_url?(url)
      DownloadCandidate::HTTP_BASED_PROTOCOLS.include?(URI(url).scheme)
    rescue TypeError, URI::InvalidURIError
      false
    end

    def directory_file_urls(directory_url, timeout:, redirects_remaining: DEFAULT_REDIRECT_LIMIT)
      request_uri = URI(directory_url)
      response = get_http_response(request_uri, timeout: timeout)

      case response
      when Net::HTTPSuccess
        response.body.scan(FASTQ_HREF_PATTERN).map do |match|
          href = CGI.unescapeHTML(match.last)
          URI.join(request_uri, href).to_s
        end.uniq
      when Net::HTTPRedirection
        raise NetworkError, "too many redirects: #{directory_url}" if redirects_remaining <= 0

        location = response[HTTP_LOCATION_HEADER]
        raise NetworkError, "redirect without location: #{directory_url}" if location.to_s.empty?

        directory_file_urls(
          URI.join(request_uri, location).to_s,
          timeout: timeout,
          redirects_remaining: redirects_remaining - 1
        )
      else
        raise NetworkError, "HTTP #{response.code}: #{directory_url}"
      end
    rescue Timeout::Error, IOError, SocketError, SystemCallError, URI::InvalidURIError => error
      raise NetworkError, fetch_failure_message(directory_url, error), cause: error
    end

    def head_content_length(request_url, timeout:, redirects_remaining: DEFAULT_REDIRECT_LIMIT)
      request_uri = URI(request_url)
      response = head_http_response(request_uri, timeout: timeout)

      case response
      when Net::HTTPSuccess
        response.content_length
      when Net::HTTPRedirection
        raise NetworkError, "too many redirects: #{request_url}" if redirects_remaining <= 0

        location = response[HTTP_LOCATION_HEADER]
        raise NetworkError, "redirect without location: #{request_url}" if location.to_s.empty?

        head_content_length(
          URI.join(request_uri, location).to_s,
          timeout: timeout,
          redirects_remaining: redirects_remaining - 1
        )
      else
        raise NetworkError, "HTTP #{response.code}: #{request_url}"
      end
    rescue Timeout::Error, IOError, SocketError, SystemCallError, URI::InvalidURIError => error
      raise NetworkError, fetch_failure_message(request_url, error), cause: error
    end

    def safe_head_content_length(request_url, timeout:)
      head_content_length(request_url, timeout: timeout)
    rescue Error
      nil
    end

    def get_http_response(request_uri, timeout:)
      Net::HTTP.start(
        request_uri.host,
        request_uri.port,
        use_ssl: request_uri.scheme == HTTPS_SCHEME,
        open_timeout: timeout,
        read_timeout: timeout
      ) do |http|
        http.get(request_uri.request_uri, USER_AGENT_HEADER => user_agent)
      end
    end

    def head_http_response(request_uri, timeout:)
      Net::HTTP.start(
        request_uri.host,
        request_uri.port,
        use_ssl: request_uri.scheme == HTTPS_SCHEME,
        open_timeout: timeout,
        read_timeout: timeout
      ) do |http|
        http.head(request_uri.request_uri, USER_AGENT_HEADER => user_agent)
      end
    end

    def user_agent
      "#{NAME}/#{VERSION}"
    end

    def fetch_failure_message(url, error)
      "failed to fetch #{url}: #{error.class}: #{error.message}"
    end
  end
end
