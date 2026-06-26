# frozen_string_literal: true

require "json"
require "net/http"
require "timeout"
require "uri"

require_relative "errors"
require_relative "version"

module Ddbj
  module Get
    class Client
      DEFAULT_BASE_URL = "https://ddbj.nig.ac.jp/resource"

      def initialize(base_url: DEFAULT_BASE_URL, open_timeout: 10, read_timeout: 30)
        @base_url = base_url.delete_suffix("/")
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      def resource(type, accession)
        get_json("#{@base_url}/#{type}/#{accession}.json")
      end

      private

      def get_json(url)
        uri = URI(url)
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: @open_timeout,
          read_timeout: @read_timeout
        ) do |http|
          http.get(uri.request_uri, "User-Agent" => "ddbj-get/#{VERSION}")
        end

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPNotFound
          raise NotFoundError, "not found: #{url}"
        else
          raise NetworkError, "HTTP #{response.code}: #{url}"
        end
      rescue JSON::ParserError => e
        raise NetworkError, "invalid JSON from #{url}: #{e.message}"
      rescue Timeout::Error, IOError, SystemCallError => e
        raise NetworkError, "#{e.class}: #{e.message}"
      end
    end
  end
end
