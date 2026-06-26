# frozen_string_literal: true

require_relative 'test_helper'

class RunRecordCollectorTest < Minitest::Test
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

  def test_collects_run_records_from_url_xrefs
    run_record = {
      'type' => 'sra-run',
      'accession' => 'DRR000001',
      'downloadUrl' => []
    }
    client = FakeClient.new(%w[sra-run DRR000001] => run_record)
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'dbXrefs' => [
        {
          'type' => 'sra-run',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/DRR000001.json'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [%w[sra-run DRR000001]], client.calls
  end

  def test_collects_run_records_from_identifier_xrefs_once
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'DRR000001',
      'distribution' => []
    }
    client = FakeClient.new(%w[sra-run DRR000001] => run_record)
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'dbXrefs' => [
        { 'type' => 'sra-run', 'identifier' => 'DRR000001' },
        { 'type' => 'sra-run', 'identifier' => 'DRR000001' }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [%w[sra-run DRR000001]], client.calls
  end

  def test_collects_run_records_from_bioproject_with_json_distribution
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'SRR4158183',
      'distribution' => [
        {
          'type' => 'DataDownload',
          'encodingFormat' => 'SRA',
          'contentUrl' => 'https://example.test/SRR4158183.sra'
        }
      ]
    }
    client = FakeClient.new(%w[sra-run SRR4158183] => run_record)
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'distribution' => [
        {
          'type' => 'DataDownload',
          'encodingFormat' => 'JSON',
          'contentUrl' => 'https://ddbj.nig.ac.jp/search/entry/bioproject/PRJNA341783.json'
        }
      ],
      'dbXrefs' => [
        {
          'type' => 'sra-run',
          'identifier' => 'SRR4158183',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/SRR4158183'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [%w[sra-run SRR4158183]], client.calls
  end

  def test_explicit_non_run_type_is_not_treated_as_run_by_download_url
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'DRR000001',
      'distribution' => []
    }
    client = FakeClient.new(%w[sra-run DRR000001] => run_record)
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'identifier' => 'PRJDB1',
      'downloadUrl' => [],
      'dbXrefs' => [
        {
          'type' => 'sra-run',
          'identifier' => 'DRR000001',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/DRR000001'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [%w[sra-run DRR000001]], client.calls
  end

  def test_recursively_collects_run_records_when_direct_run_xrefs_are_absent
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'SRR4158183',
      'distribution' => []
    }
    experiment_record = {
      'type' => 'sra-experiment',
      'identifier' => 'SRX2134150',
      'dbXrefs' => [
        {
          'type' => 'sra-run',
          'identifier' => 'SRR4158183',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/SRR4158183'
        }
      ]
    }
    client = FakeClient.new(
      %w[sra-experiment SRX2134150] => experiment_record,
      %w[sra-run SRR4158183] => run_record
    )
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'dbXrefs' => [
        {
          'type' => 'sra-experiment',
          'identifier' => 'SRX2134150',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-experiment/SRX2134150'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [
      %w[sra-experiment SRX2134150],
      %w[sra-run SRR4158183]
    ], client.calls
  end

  def test_prefers_direct_run_xrefs_over_broader_recursive_xrefs
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'SRR4158183',
      'distribution' => []
    }
    client = FakeClient.new(%w[sra-run SRR4158183] => run_record)
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'dbXrefs' => [
        {
          'type' => 'sra-experiment',
          'identifier' => 'SRX2134150',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-experiment/SRX2134150'
        },
        {
          'type' => 'sra-run',
          'identifier' => 'SRR4158183',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/SRR4158183'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [%w[sra-run SRR4158183]], client.calls
  end

  def test_rejects_large_recursive_xref_expansion
    client = FakeClient.new({})
    collector = Dratools::RunRecordCollector.new(client: client)
    xrefs = 101.times.map do |index|
      {
        'type' => 'sra-experiment',
        'identifier' => "ERX#{index}",
        'url' => "https://ddbj.nig.ac.jp/search/entry/sra-experiment/ERX#{index}"
      }
    end

    error = assert_raises(Dratools::InvalidRecordError) do
      collector.collect_run_records(
        'type' => 'sra-study',
        'identifier' => 'ERP005466',
        'dbXrefs' => xrefs
      )
    end

    assert_includes error.message, 'ERP005466 has 101 linked non-run records'
    assert_empty client.calls
  end

  def test_recursive_xref_limit_uses_environment
    client = FakeClient.new({})
    collector = Dratools::RunRecordCollector.new(client: client)
    xrefs = 2.times.map do |index|
      {
        'type' => 'sra-experiment',
        'identifier' => "ERX#{index}",
        'url' => "https://ddbj.nig.ac.jp/search/entry/sra-experiment/ERX#{index}"
      }
    end

    with_env('DRATOOLS_MAX_RECURSIVE_NON_RUN_XREFS' => '1') do
      error = assert_raises(Dratools::InvalidRecordError) do
        collector.collect_run_records(
          'type' => 'sra-study',
          'identifier' => 'ERP_LIMIT',
          'dbXrefs' => xrefs
        )
      end

      assert_includes error.message, 'ERP_LIMIT has 2 linked non-run records'
    end
  end

  def test_does_not_reject_many_direct_run_xrefs
    run_records = 101.times.to_h do |index|
      accession = "SRR#{index}"
      [
        ['sra-run', accession],
        {
          'type' => 'sra-run',
          'identifier' => accession,
          'distribution' => []
        }
      ]
    end
    client = FakeClient.new(run_records)
    collector = Dratools::RunRecordCollector.new(client: client)
    xrefs = 101.times.map do |index|
      accession = "SRR#{index}"
      {
        'type' => 'sra-run',
        'identifier' => accession,
        'url' => "https://ddbj.nig.ac.jp/search/entry/sra-run/#{accession}"
      }
    end

    records = collector.collect_run_records(
      'type' => 'bioproject',
      'identifier' => 'PRJNA_MANY_RUNS',
      'dbXrefs' => xrefs
    )

    assert_equal 101, records.length
    assert_equal 101, client.calls.length
  end

  def test_can_return_large_direct_run_xrefs_without_fetching_records
    client = FakeClient.new({})
    collector = Dratools::RunRecordCollector.new(client: client)
    xrefs = 6.times.map do |index|
      accession = "SRR#{index}"
      {
        'type' => 'sra-run',
        'identifier' => accession,
        'url' => "https://ddbj.nig.ac.jp/search/entry/sra-run/#{accession}"
      }
    end

    tree = collector.explore(
      {
        'type' => 'bioproject',
        'identifier' => 'PRJNA_MANY_RUNS',
        'dbXrefs' => xrefs
      },
      direct_run_fetch_limit: 5
    )

    assert_equal 6, tree.children.length
    assert_equal %w[SRR0 SRR1 SRR2 SRR3 SRR4 SRR5], tree.run_accessions
    assert_empty tree.run_records
    assert_empty client.calls
  end

  def test_collects_run_records_from_child_bioprojects
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'SRR17168265',
      'distribution' => []
    }
    child_bioproject_record = {
      'type' => 'bioproject',
      'identifier' => 'PRJNA341783',
      'dbXrefs' => [
        {
          'type' => 'sra-run',
          'identifier' => 'SRR17168265',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/SRR17168265'
        }
      ]
    }
    client = FakeClient.new(
      %w[bioproject PRJNA341783] => child_bioproject_record,
      %w[sra-run SRR17168265] => run_record
    )
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'objectType' => 'UmbrellaBioProject',
      'childBioProjects' => [
        {
          'type' => 'bioproject',
          'identifier' => 'PRJNA341783',
          'url' => 'https://ddbj.nig.ac.jp/search/entry/bioproject/PRJNA341783'
        }
      ],
      'dbXrefs' => [
        {
          'type' => 'geo',
          'identifier' => 'GSE190459',
          'url' => 'https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE190459'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [
      %w[bioproject PRJNA341783],
      %w[sra-run SRR17168265]
    ], client.calls
  end

  def test_explore_returns_traversal_tree
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'SRR17168265',
      'distribution' => []
    }
    client = FakeClient.new(%w[sra-run SRR17168265] => run_record)
    collector = Dratools::RunRecordCollector.new(client: client)

    tree = collector.explore({
                               'type' => 'bioproject',
                               'identifier' => 'PRJNA341783',
                               'dbXrefs' => [
                                 {
                                   'type' => 'sra-run',
                                   'identifier' => 'SRR17168265',
                                   'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/SRR17168265'
                                 }
                               ]
                             })

    assert_equal 'bioproject', tree.type
    assert_equal 'PRJNA341783', tree.accession
    assert_equal ['SRR17168265'], tree.children.map(&:accession)
    assert_equal [run_record], tree.run_records
  end

  def test_explore_can_keep_fetch_errors_as_nodes
    client = Class.new do
      def fetch_resource_record(_type, _accession)
        raise Dratools::NetworkError, 'HTTP 500'
      end
    end.new
    collector = Dratools::RunRecordCollector.new(client: client)

    tree = collector.explore(
      {
        'type' => 'bioproject',
        'identifier' => 'PRJNA1',
        'dbXrefs' => [
          {
            'type' => 'sra-run',
            'identifier' => 'SRR1',
            'url' => 'https://ddbj.nig.ac.jp/search/entry/sra-run/SRR1'
          }
        ]
      },
      tolerant: true
    )

    assert_equal 'SRR1', tree.children.first.accession
    assert_equal 'HTTP 500', tree.children.first.error
  end
end
