# frozen_string_literal: true

require 'uri'

require_relative 'errors'

module Dratools
  # 1 件のダウンロード候補を表す値オブジェクト。
  class DownloadCandidate
    FTP_PROTOCOL = 'ftp'
    HTTPS_PROTOCOL = 'https'
    HTTP_PROTOCOL = 'http'
    HTTP_BASED_PROTOCOLS = [HTTPS_PROTOCOL, HTTP_PROTOCOL].freeze

    attr_reader :run_accession, :type, :url, :ftp_url, :size, :md5

    def initialize(type:, run_accession: nil, url: nil, ftp_url: nil, size: nil, md5: nil)
      @run_accession = run_accession
      @type = type
      @url = url
      @ftp_url = ftp_url
      @size = size
      @md5 = md5
    end

    def url_for_protocol(protocol)
      case protocol.to_s
      when FTP_PROTOCOL
        ftp_url || url
      when *HTTP_BASED_PROTOCOLS
        url || ftp_url
      else
        raise InvalidProtocolError, "unknown protocol: #{protocol}"
      end
    end

    def filename_for_protocol(protocol = HTTPS_PROTOCOL)
      File.basename(URI(url_for_protocol(protocol)).path)
    end

    def directory_url_for_protocol?(protocol = HTTPS_PROTOCOL)
      URI(url_for_protocol(protocol)).path.end_with?('/')
    end
  end
end
