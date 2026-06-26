# frozen_string_literal: true

require_relative 'test_helper'

class DdbjResourceClientTest < Minitest::Test
  class FakeClient < Dratools::DdbjResourceClient
    def initialize(responses)
      super()
      @responses = responses
    end

    private

    def get_http_response(request_uri)
      @responses.fetch(request_uri.to_s)
    end
  end

  def test_resource_follows_redirects
    redirect = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redirect['location'] = 'https://ddbj.nig.ac.jp/archive/resource/sra-run/DRR000001.json'

    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success.instance_variable_set(:@read, true)
    success.body = '{"type":"sra-run","accession":"DRR000001"}'

    client = FakeClient.new(
      'https://ddbj.nig.ac.jp/resource/sra-run/DRR000001.json' => redirect,
      'https://ddbj.nig.ac.jp/archive/resource/sra-run/DRR000001.json' => success
    )

    ddbj_record = client.fetch_resource_record('sra-run', 'DRR000001')

    assert_equal 'sra-run', ddbj_record['type']
    assert_equal 'DRR000001', ddbj_record['accession']
  end

  def test_resource_wraps_name_resolution_failures
    client = Class.new(Dratools::DdbjResourceClient) do
      private

      def get_http_response(_request_uri)
        raise SocketError, 'getaddrinfo: temporary failure in name resolution'
      end
    end.new

    error = assert_raises(Dratools::NetworkError) do
      client.fetch_resource_record('sra-run', 'DRR000001')
    end

    assert_includes error.message, 'failed to fetch https://ddbj.nig.ac.jp/resource/sra-run/DRR000001.json'
    assert_includes error.message, 'SocketError'
  end
end
