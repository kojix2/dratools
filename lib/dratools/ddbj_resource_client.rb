# frozen_string_literal: true

require 'json'
require 'net/http'
require 'timeout'
require 'uri'

require_relative 'errors'
require_relative 'version'
require_relative 'ddbj_record_fields'

module Dratools
  # DDBJ Search API を呼び出す薄い HTTP クライアント。
  class DdbjResourceClient
    DDBJ_SEARCH_API_BASE_URL = 'https://ddbj.nig.ac.jp/search/api'
    ENTRIES_PATH = 'entries'
    DBLINK_PATH = 'dblink'
    ENTRY_RECORD_EXTENSION = '.json'
    BULK_MAX_IDS = 1000
    DBLINK_COUNTS_MAX_ITEMS = 100
    HTTPS_SCHEME = 'https'
    HTTP_LOCATION_HEADER = 'location'
    USER_AGENT_HEADER = 'User-Agent'
    DEFAULT_REDIRECT_LIMIT = 5
    DEFAULT_OPEN_TIMEOUT_SECONDS = 10
    DEFAULT_READ_TIMEOUT_SECONDS = 30

    def initialize(base_url: DDBJ_SEARCH_API_BASE_URL, open_timeout: DEFAULT_OPEN_TIMEOUT_SECONDS,
                   read_timeout: DEFAULT_READ_TIMEOUT_SECONDS)
      @base_url = base_url.delete_suffix('/')
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def fetch_resource_record(type, accession)
      fetch_json("#{@base_url}/#{ENTRIES_PATH}/#{type}/#{accession}#{ENTRY_RECORD_EXTENSION}")
    end

    def fetch_db_links(type, accession, target: nil)
      request_uri = URI("#{@base_url}/#{DBLINK_PATH}/#{type}/#{accession}")
      request_uri.query = URI.encode_www_form(target: target) if target
      fetch_json(request_uri.to_s).fetch(DdbjRecordFields::DB_XREFS_KEY, [])
    end

    def fetch_resource_records_bulk(type, accessions, include_db_xrefs: false)
      accessions.each_slice(BULK_MAX_IDS).with_object({}) do |chunk, records|
        records.merge!(
          fetch_resource_records_bulk_chunk(type, chunk, include_db_xrefs: include_db_xrefs)
        )
      end
    end

    def fetch_db_link_counts(items)
      items.each_slice(DBLINK_COUNTS_MAX_ITEMS).with_object({}) do |chunk, counts|
        counts.merge!(fetch_db_link_counts_chunk(chunk))
      end
    end

    private

    def fetch_db_link_counts_chunk(items)
      request_url = "#{@base_url}/#{DBLINK_PATH}/counts"
      payload = post_json(request_url, items: items)
      payload.fetch('items', []).to_h do |item|
        [[item['type'], item[DdbjRecordFields::IDENTIFIER_KEY]], item.fetch('counts', {})]
      end
    end

    def fetch_resource_records_bulk_chunk(type, accessions, include_db_xrefs:)
      request_uri = URI("#{@base_url}/#{ENTRIES_PATH}/#{type}/bulk")
      request_uri.query = URI.encode_www_form(includeDbXrefs: include_db_xrefs)
      payload = post_json(request_uri.to_s, ids: accessions)
      payload.fetch('entries', []).to_h do |record|
        accession = record[DdbjRecordFields::IDENTIFIER_KEY] ||
                    record[DdbjRecordFields::ACCESSION_KEY] ||
                    record[DdbjRecordFields::ID_KEY] ||
                    record[DdbjRecordFields::PRIMARY_ID_KEY]
        [accession, record]
      end
    end

    def fetch_json(request_url, redirects_remaining = DEFAULT_REDIRECT_LIMIT)
      with_network_errors(request_url) do
        request_uri = URI(request_url)
        response = get_http_response(request_uri)

        case response
        when Net::HTTPSuccess
          parse_json_response(response, request_url)
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
      end
    end

    def post_json(request_url, payload)
      with_network_errors(request_url) do
        response = post_http_response(URI(request_url), payload)
        return parse_json_response(response, request_url) if response.is_a?(Net::HTTPSuccess)
        raise NotFoundError, "not found: #{request_url}" if response.is_a?(Net::HTTPNotFound)

        raise NetworkError, "HTTP #{response.code}: #{request_url}"
      end
    end

    def parse_json_response(response, request_url)
      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise NetworkError, "invalid JSON from #{request_url}: #{error.message}", cause: error
    end

    def with_network_errors(request_url)
      yield
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

    def post_http_response(request_uri, payload)
      Net::HTTP.start(
        request_uri.host,
        request_uri.port,
        use_ssl: request_uri.scheme == HTTPS_SCHEME,
        open_timeout: @open_timeout,
        read_timeout: @read_timeout
      ) do |http|
        request = Net::HTTP::Post.new(request_uri.request_uri, USER_AGENT_HEADER => user_agent)
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(payload)
        http.request(request)
      end
    end

    def user_agent
      "#{NAME}/#{VERSION}"
    end
  end
end
