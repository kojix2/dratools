# frozen_string_literal: true

require_relative 'test_helper'

class AccessionResolverTest < Minitest::Test
  class FakeClient
    attr_reader :calls

    def initialize(records)
      @records = records
      @calls = []
    end

    def fetch_resource_record(type, accession)
      @calls << [type, accession]
      @records.fetch([type, accession])
    end
  end

  def test_resolves_run_sra_download
    client = FakeClient.new(
      %w[sra-run DRR000001] => {
        'type' => 'sra-run',
        'accession' => 'DRR000001',
        'downloadUrl' => [
          {
            'type' => 'sra',
            'url' => 'https://ddbj.nig.ac.jp/public/ddbj_database/dra/sra/x/DRR000001.sra',
            'ftpUrl' => 'ftp://ftp.ddbj.nig.ac.jp/ddbj_database/dra/sra/x/DRR000001.sra',
            'size' => 123
          },
          {
            'type' => 'fastq',
            'url' => 'https://ddbj.nig.ac.jp/public/ddbj_database/dra/fastq/x/DRR000001.fastq.bz2'
          }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads('DRR000001')

    assert_equal 1, downloads.length
    assert_equal 'DRR000001', downloads.first.run_accession
    assert_equal 'sra', downloads.first.type
    assert_equal 123, downloads.first.size
  end

  def test_resolves_bioproject_to_runs
    client = FakeClient.new(
      %w[bioproject PRJDB1] => {
        'type' => 'bioproject',
        'accession' => 'PRJDB1',
        'dbXrefs' => [
          {
            'type' => 'sra-run',
            'url' => 'https://ddbj.nig.ac.jp/resource/sra-run/DRR000001'
          }
        ]
      },
      %w[sra-run DRR000001] => {
        'type' => 'sra-run',
        'accession' => 'DRR000001',
        'downloadUrl' => [
          {
            'type' => 'sra',
            'url' => 'https://example.test/DRR000001.sra'
          }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads('PRJDB1')

    assert_equal ['https://example.test/DRR000001.sra'], downloads.map(&:url)
  end

  def test_resolves_downloads_from_already_fetched_record
    root_record = {
      'type' => 'bioproject',
      'accession' => 'PRJDB1',
      'dbXrefs' => [
        {
          'type' => 'sra-run',
          'identifier' => 'DRR000001'
        }
      ]
    }
    client = FakeClient.new(
      %w[sra-run DRR000001] => {
        'type' => 'sra-run',
        'accession' => 'DRR000001',
        'downloadUrl' => [
          {
            'type' => 'sra',
            'url' => 'https://example.test/DRR000001.sra'
          }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads_from_record('PRJDB1', root_record)

    assert_equal ['https://example.test/DRR000001.sra'], downloads.map(&:url)
    assert_equal [%w[sra-run DRR000001]], client.calls
  end

  def test_resolves_prjda_bioproject_accession
    client = FakeClient.new(
      %w[bioproject PRJDA39275] => {
        'type' => 'bioproject',
        'accession' => 'PRJDA39275',
        'dbXrefs' => [
          {
            'type' => 'sra-run',
            'identifier' => 'DRR000002',
            'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/DRR000002'
          }
        ]
      },
      %w[sra-run DRR000002] => {
        'type' => 'sra-run',
        'accession' => 'DRR000002',
        'downloadUrl' => [
          {
            'type' => 'sra',
            'url' => 'https://example.test/DRR000002.sra'
          }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads('PRJDA39275')

    assert_equal ['https://example.test/DRR000002.sra'], downloads.map(&:url)
  end

  def test_resolves_prjea_bioproject_accession
    client = FakeClient.new(
      %w[bioproject PRJEA12345] => {
        'type' => 'bioproject',
        'accession' => 'PRJEA12345',
        'dbXrefs' => [
          {
            'type' => 'sra-run',
            'identifier' => 'ERR000001'
          }
        ]
      },
      %w[sra-run ERR000001] => {
        'type' => 'sra-run',
        'accession' => 'ERR000001',
        'distribution' => [
          {
            'encodingFormat' => 'SRA',
            'contentUrl' => 'https://example.test/ERR000001.sra'
          }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads('PRJEA12345')

    assert_equal ['https://example.test/ERR000001.sra'], downloads.map(&:url)
  end

  def test_filters_fastq_downloads
    client = FakeClient.new(
      %w[sra-run DRR000001] => {
        'downloadUrl' => [
          { 'type' => 'sra', 'url' => 'https://example.test/DRR000001.sra' },
          { 'type' => 'fastq', 'url' => 'https://example.test/DRR000001.fastq.bz2' }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads('DRR000001', file_type: 'fastq')

    assert_equal ['fastq'], downloads.map(&:type)
  end

  def test_resolves_distribution_downloads_from_current_api_shape
    client = FakeClient.new(
      %w[sra-run DRR000001] => {
        'type' => 'sra-run',
        'identifier' => 'DRR000001',
        'distribution' => [
          {
            'type' => 'DataDownload',
            'encodingFormat' => 'JSON',
            'contentUrl' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/DRR000001.json'
          },
          {
            'type' => 'DataDownload',
            'encodingFormat' => 'FASTQ',
            'contentUrl' => 'https://ddbj.nig.ac.jp/public/ddbj_database/dra/fastq/DRA000/DRR000001/'
          },
          {
            'type' => 'DataDownload',
            'encodingFormat' => 'SRA',
            'contentUrl' => 'https://ddbj.nig.ac.jp/public/ddbj_database/dra/sra/x/DRR000001.sra'
          }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads('DRR000001')

    assert_equal 1, downloads.length
    assert_equal 'DRR000001', downloads.first.run_accession
    assert_equal 'sra', downloads.first.type
    expected_url = 'https://ddbj.nig.ac.jp/public/ddbj_database/dra/sra/x/DRR000001.sra'
    assert_equal expected_url, downloads.first.url
  end

  def test_resolves_xref_identifier_without_url
    client = FakeClient.new(
      %w[bioproject PRJDB1] => {
        'type' => 'bioproject',
        'identifier' => 'PRJDB1',
        'dbXrefs' => [
          {
            'type' => 'sra-run',
            'identifier' => 'DRR000001'
          }
        ]
      },
      %w[sra-run DRR000001] => {
        'type' => 'sra-run',
        'identifier' => 'DRR000001',
        'distribution' => [
          {
            'type' => 'DataDownload',
            'encodingFormat' => 'SRA',
            'contentUrl' => 'https://example.test/DRR000001.sra'
          }
        ]
      }
    )
    resolver = Dratools::AccessionResolver.new(client: client)

    downloads = resolver.resolve_downloads('PRJDB1')

    assert_equal ['https://example.test/DRR000001.sra'], downloads.map(&:url)
  end

  def test_rejects_unknown_accession
    resolver = Dratools::AccessionResolver.new(client: FakeClient.new({}))

    assert_raises(Dratools::UnsupportedAccessionError) do
      resolver.resolve_downloads('XYZ123')
    end
  end
end
