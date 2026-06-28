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

    def fetch_resource_records_bulk(type, accessions, include_db_xrefs: false)
      @calls << ['bulk', type, accessions, include_db_xrefs]
      accessions.to_h { |accession| [accession, @records.fetch([type, accession])] }
    end
  end

  def test_collects_run_records_from_identifier_xrefs
    run_record = {
      'type' => 'sra-run',
      'accession' => 'DRR000001',
      'distribution' => []
    }
    client = FakeClient.new(%w[sra-run DRR000001] => run_record)
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'dbXrefs' => [
        {
          'type' => 'sra-run',
          'identifier' => 'DRR000001'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [['bulk', 'sra-run', %w[DRR000001], false]], client.calls
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
    assert_equal [['bulk', 'sra-run', %w[DRR000001], false]], client.calls
  end

  def test_collects_direct_run_records_with_bulk_fetch
    run_records = {
      %w[sra-run DRR000001] => {
        'type' => 'sra-run',
        'identifier' => 'DRR000001',
        'distribution' => []
      },
      %w[sra-run DRR000002] => {
        'type' => 'sra-run',
        'identifier' => 'DRR000002',
        'distribution' => []
      }
    }
    client = FakeClient.new(run_records)
    collector = Dratools::RunRecordCollector.new(client: client)

    records = collector.collect_run_records(
      'type' => 'bioproject',
      'dbXrefs' => [
        { 'type' => 'sra-run', 'identifier' => 'DRR000001' },
        { 'type' => 'sra-run', 'identifier' => 'DRR000002' }
      ]
    )

    identifiers = records.map { |record| record['identifier'] }
    assert_equal %w[DRR000001 DRR000002], identifiers
    assert_equal [
      ['bulk', 'sra-run', %w[DRR000001 DRR000002], false]
    ], client.calls
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
          'identifier' => 'SRR4158183'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [['bulk', 'sra-run', %w[SRR4158183], false]], client.calls
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
          'identifier' => 'SRR4158183'
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
          'identifier' => 'SRX2134150'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [
      %w[sra-experiment SRX2134150],
      ['bulk', 'sra-run', %w[SRR4158183], false]
    ], client.calls
  end

  def test_recursively_collects_run_records_from_each_supported_parent_type
    run_record = {
      'type' => 'sra-run',
      'identifier' => 'SRR000001',
      'distribution' => []
    }
    parent_xrefs = [
      ['sra-experiment', 'SRX000001'],
      ['sra-sample', 'SRS000001'],
      ['sra-study', 'SRP000001'],
      ['sra-submission', 'SRA000001'],
      ['bioproject', 'PRJNA000001'],
      ['biosample', 'SAMN000001']
    ]
    parent_records = parent_xrefs.to_h do |type, accession|
      [
        [type, accession],
        {
          'type' => type,
          'identifier' => accession,
          'dbXrefs' => [
            {
              'type' => 'sra-run',
              'identifier' => 'SRR000001'
            }
          ]
        }
      ]
    end
    client = FakeClient.new(parent_records.merge(%w[sra-run SRR000001] => run_record))
    collector = Dratools::RunRecordCollector.new(client: client)

    run_records = collector.collect_run_records(
      'type' => 'bioproject',
      'identifier' => 'PRJNA_PARENT',
      'dbXrefs' => parent_xrefs.map do |type, accession|
        {
          'type' => type,
          'identifier' => accession
        }
      end
    )

    assert_equal [run_record], run_records
    assert_equal parent_xrefs, client.calls.select { |call| call.length == 2 }
    assert_equal [
      ['bulk', 'sra-run', %w[SRR000001], false]
    ], client.calls.select { |call| call.first == 'bulk' }
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
          'identifier' => 'SRX2134150'
        },
        {
          'type' => 'sra-run',
          'identifier' => 'SRR4158183'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [['bulk', 'sra-run', %w[SRR4158183], false]], client.calls
  end

  def test_rejects_large_recursive_xref_expansion
    client = FakeClient.new({})
    collector = Dratools::RunRecordCollector.new(client: client)
    xrefs = 101.times.map do |index|
      {
        'type' => 'sra-experiment',
        'identifier' => "ERX#{index}"
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
        'identifier' => "ERX#{index}"
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
        'identifier' => accession
      }
    end

    records = collector.collect_run_records(
      'type' => 'bioproject',
      'identifier' => 'PRJNA_MANY_RUNS',
      'dbXrefs' => xrefs
    )

    assert_equal 101, records.length
    assert_equal [
      ['bulk', 'sra-run', xrefs.map { |xref| xref['identifier'] }, false]
    ], client.calls
  end

  def test_can_return_large_direct_run_xrefs_without_fetching_records
    client = FakeClient.new({})
    collector = Dratools::RunRecordCollector.new(client: client)
    xrefs = 6.times.map do |index|
      accession = "SRR#{index}"
      {
        'type' => 'sra-run',
        'identifier' => accession
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
          'identifier' => 'SRR17168265'
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
          'identifier' => 'PRJNA341783'
        }
      ],
      'dbXrefs' => [
        {
          'type' => 'geo',
          'identifier' => 'GSE190459'
        }
      ]
    )

    assert_equal [run_record], run_records
    assert_equal [
      %w[bioproject PRJNA341783],
      ['bulk', 'sra-run', %w[SRR17168265], false]
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
                                   'identifier' => 'SRR17168265'
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
      def fetch_resource_records_bulk(_type, accessions, include_db_xrefs: false) # rubocop:disable Lint/UnusedMethodArgument
        accessions.to_h { |accession| [accession, nil] }
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
            'identifier' => 'SRR1'
          }
        ]
      },
      tolerant: true
    )

    assert_equal 'SRR1', tree.children.first.accession
    assert_equal 'not found: SRR1', tree.children.first.error
  end
end
