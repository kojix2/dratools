# frozen_string_literal: true

require 'json'
require 'net/http'
require 'timeout'
require 'uri'

require_relative 'errors'
require_relative 'version'

module Dratools
  # DDBJ resource API を呼び出す薄い HTTP クライアント。
  class DdbjResourceClient
    DDBJ_RESOURCE_BASE_URL = 'https://ddbj.nig.ac.jp/resource'
    RESOURCE_RECORD_EXTENSION = '.json'
    HTTPS_SCHEME = 'https'
    HTTP_LOCATION_HEADER = 'location'
    USER_AGENT_HEADER = 'User-Agent'
    DEFAULT_REDIRECT_LIMIT = 5
    DEFAULT_OPEN_TIMEOUT_SECONDS = 10
    DEFAULT_READ_TIMEOUT_SECONDS = 30

    def initialize(base_url: DDBJ_RESOURCE_BASE_URL, open_timeout: DEFAULT_OPEN_TIMEOUT_SECONDS,
                   read_timeout: DEFAULT_READ_TIMEOUT_SECONDS)
      @base_url = base_url.delete_suffix('/')
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def fetch_resource_record(type, accession)
      fetch_json("#{@base_url}/#{type}/#{accession}#{RESOURCE_RECORD_EXTENSION}")
    end

    private

    def fetch_json(request_url, redirects_remaining = DEFAULT_REDIRECT_LIMIT)
      request_uri = URI(request_url)
      response = get_http_response(request_uri)

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPRedirection
        raise NetworkError, "too many redirects: #{request_url}" if redirects_remaining <= 0

        location = response[HTTP_LOCATION_HEADER]
        raise NetworkError, "redirect without location: #{request_url}" if location.to_s.empty?

        fetch_json(URI.join(request_uri, location).to_s, redirects_remaining - 1)
      when Net::HTTPNotFound
        raise NotFoundError, "not found: #{request_url}"
      else
        raise NetworkError, "HTTP #{response.code}: #{request_url}"
      end
    rescue JSON::ParserError => error
      raise NetworkError, "invalid JSON from #{request_url}: #{error.message}", cause: error
    rescue Timeout::Error, IOError, SocketError, SystemCallError => error
      message = "failed to fetch #{request_url}: #{error.class}: #{error.message}"
      raise NetworkError, message, cause: error
    end

    def get_http_response(request_uri)
      Net::HTTP.start(
        request_uri.host,
        request_uri.port,
        use_ssl: request_uri.scheme == HTTPS_SCHEME,
        open_timeout: @open_timeout,
        read_timeout: @read_timeout
      ) do |http|
        http.get(request_uri.request_uri, USER_AGENT_HEADER => user_agent)
      end
    end

    def user_agent
      "#{NAME}/#{VERSION}"
    end
  end
end
