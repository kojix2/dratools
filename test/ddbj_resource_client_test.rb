# frozen_string_literal: true

require_relative 'test_helper'

class DdbjResourceClientTest < Minitest::Test
  class FakeClient < Dratools::DdbjResourceClient
    attr_reader :posts

    def initialize(responses)
      super()
      @responses = responses
      @posts = []
    end

    private

    def get_http_response(request_uri)
      @responses.fetch(request_uri.to_s)
    end

    def post_http_response(request_uri, payload)
      @posts << [request_uri.to_s, payload]
      @responses.fetch(request_uri.to_s)
    end
  end

  def test_entry_fetch_follows_redirects
    redirect = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redirect['location'] = 'https://ddbj.nig.ac.jp/archive/search/api/entries/sra-run/DRR000001.json'

    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success.instance_variable_set(:@read, true)
    success.body = '{"type":"sra-run","accession":"DRR000001"}'

    client = FakeClient.new(
      'https://ddbj.nig.ac.jp/search/api/entries/sra-run/DRR000001.json' => redirect,
      'https://ddbj.nig.ac.jp/archive/search/api/entries/sra-run/DRR000001.json' => success
    )

    ddbj_record = client.fetch_resource_record('sra-run', 'DRR000001')

    assert_equal 'sra-run', ddbj_record['type']
    assert_equal 'DRR000001', ddbj_record['accession']
  end

  def test_entry_fetch_wraps_name_resolution_failures
    client = Class.new(Dratools::DdbjResourceClient) do
      private

      def get_http_response(_request_uri)
        raise SocketError, 'getaddrinfo: temporary failure in name resolution'
      end
    end.new

    error = assert_raises(Dratools::NetworkError) do
      client.fetch_resource_record('sra-run', 'DRR000001')
    end

    assert_includes error.message, 'failed to fetch https://ddbj.nig.ac.jp/search/api/entries/sra-run/DRR000001.json'
    assert_includes error.message, 'SocketError'
  end

  def test_fetches_db_links_with_target
    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success.instance_variable_set(:@read, true)
    success.body = '{"dbXrefs":[{"type":"sra-run","identifier":"DRR000001"}]}'

    client = FakeClient.new(
      'https://ddbj.nig.ac.jp/search/api/dblink/bioproject/PRJDB1?target=sra-run' => success
    )

    xrefs = client.fetch_db_links('bioproject', 'PRJDB1', target: 'sra-run')

    assert_equal [{ 'type' => 'sra-run', 'identifier' => 'DRR000001' }], xrefs
  end

  def test_fetches_bulk_records_without_dbxrefs
    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success.instance_variable_set(:@read, true)
    success.body = '{"entries":[{"type":"sra-run","identifier":"DRR000001"}],"notFound":[]}'

    client = FakeClient.new(
      'https://ddbj.nig.ac.jp/search/api/entries/sra-run/bulk?includeDbXrefs=false' => success
    )

    records = client.fetch_resource_records_bulk('sra-run', ['DRR000001'], include_db_xrefs: false)

    assert_equal 'sra-run', records['DRR000001']['type']
    assert_equal [
      [
        'https://ddbj.nig.ac.jp/search/api/entries/sra-run/bulk?includeDbXrefs=false',
        { ids: ['DRR000001'] }
      ]
    ], client.posts
  end

  def test_fetches_dblink_counts
    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success.instance_variable_set(:@read, true)
    success.body = '{"items":[{"type":"bioproject","identifier":"PRJDB1","counts":{"sra-run":2}}]}'

    client = FakeClient.new('https://ddbj.nig.ac.jp/search/api/dblink/counts' => success)

    counts = client.fetch_db_link_counts([{ type: 'bioproject', id: 'PRJDB1' }])

    assert_equal({ 'sra-run' => 2 }, counts[%w[bioproject PRJDB1]])
    assert_equal [
      [
        'https://ddbj.nig.ac.jp/search/api/dblink/counts',
        { items: [{ type: 'bioproject', id: 'PRJDB1' }] }
      ]
    ], client.posts
  end
end
