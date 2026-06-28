# frozen_string_literal: true

require 'stringio'

require_relative 'test_helper'

class CommandLineInterfaceTest < Minitest::Test
  class FakeResolver
    attr_reader :calls, :fetch_calls, :count_calls, :direct_run_calls, :tree_options

    def initialize(results: {}, records: {}, failures: {}, direct_run_counts: {},
                   direct_run_accessions: {})
      @results = results
      @records = records
      @failures = failures
      @direct_run_counts = direct_run_counts
      @direct_run_accessions = direct_run_accessions
      @calls = []
      @fetch_calls = []
      @count_calls = []
      @direct_run_calls = []
    end

    def resolve_downloads(accession, file_type:)
      @calls << [accession, file_type]
      raise @failures.fetch(accession) if @failures.key?(accession)

      @results.fetch(accession)
    end

    def resolve_downloads_from_record(accession, _ddbj_record, file_type:)
      resolve_downloads(accession, file_type: file_type)
    end

    def resolve_tree(accession, file_type:, **options)
      @calls << [accession, file_type]
      @tree_options = options
      raise @failures.fetch(accession) if @failures.key?(accession)

      Dratools::TraversalNode.new(
        type: 'bioproject',
        accession: accession,
        children: @results.fetch(accession).map do |download|
          Dratools::TraversalNode.new(
            type: 'sra-run',
            accession: download.run_accession,
            children: [
              Dratools::TraversalNode.new(
                relation: Dratools::TraversalNode::DOWNLOAD_RELATION,
                type: download.type,
                accession: download.run_accession,
                url: download.url,
                download: download
              )
            ]
          )
        end
      )
    end

    def fetch_record_for(accession)
      @fetch_calls << accession
      raise @failures.fetch(accession) if @failures.key?(accession)

      @records.fetch(accession) { { 'type' => 'unknown', 'dbXrefs' => [] } }
    end

    def resource_type_for(accession)
      accession.match?(/\A[DES]RR/) ? 'sra-run' : 'bioproject'
    end

    def direct_run_count_for(accession)
      @count_calls << accession
      @direct_run_counts.fetch(accession, 0)
    end

    def direct_run_accessions_for(accession)
      @direct_run_calls << accession
      @direct_run_accessions.fetch(accession, [])
    end
  end

  class FakeDownloader
    attr_reader :content_length_calls, :save_calls

    def initialize(save_failures: {})
      @content_length_calls = []
      @save_failures = save_failures
      @save_calls = []
    end

    def probe_download(*)
      true
    end

    def save_download(download, **options)
      @save_calls << [download, options]
      if @save_failures.key?(download.run_accession)
        raise @save_failures.fetch(download.run_accession)
      end

      Dratools::DownloadService::DownloadResult.new(path: '/tmp/downloaded.sra', skipped: false)
    end

    def content_lengths(download, **options)
      @content_length_calls << [download, options]
      [download.size]
    end
  end

  def run_cli(argv, resolver:, downloader: FakeDownloader.new, stdin: StringIO.new)
    output_stream = StringIO.new
    error_stream = StringIO.new
    exit_status = Dratools::CommandLineInterface.new(
      argv,
      resolver: resolver,
      downloader: downloader,
      stdout: output_stream,
      stderr: error_stream,
      stdin: stdin
    ).run
    [exit_status, output_stream.string, error_stream.string]
  end

  def test_url_reads_accessions_from_file_and_deduplicates
    resolver = FakeResolver.new(
      results: {
        'DRR000002' => [download_for('DRR000002')],
        'DRR000003' => [download_for('DRR000003')],
        'DRR000001' => [download_for('DRR000001')]
      }
    )

    Dir.mktmpdir do |temporary_directory|
      input_path = File.join(temporary_directory, 'accessions.txt')
      File.write(input_path, "drr000001\nDRR000002\nDRR000001\n")

      exit_status, stdout, stderr = run_cli(
        ['url', '--input', input_path, 'DRR000002', 'DRR000003'],
        resolver: resolver
      )

      assert_equal 0, exit_status
      assert_equal [
        %w[DRR000002 sra],
        %w[DRR000003 sra],
        %w[DRR000001 sra]
      ], resolver.calls
      assert_equal [
        'https://example.test/DRR000002.sra',
        'https://example.test/DRR000003.sra',
        'https://example.test/DRR000001.sra'
      ], stdout.lines(chomp: true)
      assert_empty stderr
    end
  end

  def test_url_reads_from_stdin_without_positional_accessions
    resolver = FakeResolver.new(
      results: {
        'DRR000001' => [download_for('DRR000001')],
        'DRR000002' => [download_for('DRR000002')]
      }
    )

    exit_status, stdout, stderr = run_cli(
      ['url'],
      resolver: resolver,
      stdin: StringIO.new("DRR000001\n\nDRR000002\n")
    )

    assert_equal 0, exit_status
    assert_equal [
      'https://example.test/DRR000001.sra',
      'https://example.test/DRR000002.sra'
    ], stdout.lines(chomp: true)
    assert_empty stderr
  end

  def test_url_json_outputs_metadata
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001')] })

    exit_status, stdout, = run_cli(['url', '--json', 'DRR000001'], resolver: resolver)

    assert_equal 0, exit_status
    parsed = JSON.parse(stdout)
    assert_equal 'DRR000001', parsed.first['run_accession']
    assert_equal 'https://example.test/DRR000001.sra', parsed.first['url']
  end

  def test_url_tsv_outputs_tab_separated_columns
    download = Dratools::DownloadCandidate.new(
      run_accession: 'DRR000001', type: 'sra',
      url: 'https://example.test/DRR000001.sra', size: 1024, md5: 'abc123'
    )
    resolver = FakeResolver.new(results: { 'DRR000001' => [download] })

    exit_status, stdout, stderr = run_cli(%w[url --tsv DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal [
      '#run_accession	type	url	size	md5',
      "DRR000001\tsra\thttps://example.test/DRR000001.sra\t1024\tabc123"
    ], stdout.lines(chomp: true)
    assert_empty stderr
  end

  def test_url_tsv_marks_missing_fields_as_na
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001')] })

    exit_status, stdout, = run_cli(%w[url --tsv DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal "DRR000001\tsra\thttps://example.test/DRR000001.sra\tNA\tNA",
                 stdout.lines(chomp: true)[1]
  end

  def test_url_rejects_large_direct_run_expansion
    resolver = FakeResolver.new(direct_run_counts: { 'PRJNA1' => 201 })

    exit_status, stdout, stderr = run_cli(%w[url --tsv PRJNA1], resolver: resolver)

    assert_equal 1, exit_status
    assert_empty stdout
    assert_includes stderr, 'PRJNA1 has 201 direct runs'
    assert_includes stderr, 'url expands at most 200 direct runs from one parent accession'
    assert_includes stderr, 'DRATOOLS_URL_MAX_DIRECT_RUNS=unlimited'
    assert_equal ['PRJNA1'], resolver.count_calls
    assert_empty resolver.fetch_calls
    assert_empty resolver.calls
  end

  def test_url_direct_run_limit_uses_environment
    resolver = FakeResolver.new(
      direct_run_counts: { 'PRJNA1' => 201 },
      results: { 'PRJNA1' => [download_for('SRR0')] }
    )

    with_env('DRATOOLS_URL_MAX_DIRECT_RUNS' => '201') do
      exit_status, stdout, stderr = run_cli(%w[url --tsv PRJNA1], resolver: resolver)

      assert_equal 0, exit_status
      assert_includes stdout, "SRR0\tsra\thttps://example.test/SRR0.sra"
      assert_equal ['PRJNA1'], resolver.count_calls
      assert_equal ['PRJNA1'], resolver.fetch_calls
      assert_equal [%w[PRJNA1 sra]], resolver.calls
      assert_empty stderr
    end
  end

  def test_url_returns_non_zero_and_continues_after_accession_failure
    resolver = FakeResolver.new(
      results: { 'DRR000001' => [download_for('DRR000001')] },
      failures: { 'DRR000002' => Dratools::NotFoundError.new('download URL not found') }
    )

    exit_status, stdout, stderr = run_cli(%w[url DRR000001 DRR000002], resolver: resolver)

    assert_equal 1, exit_status
    assert_equal ['https://example.test/DRR000001.sra'], stdout.lines(chomp: true)
    assert_includes stderr, 'dratools url: DRR000002: download URL not found'
  end

  def test_returns_non_zero_when_accession_is_missing
    exit_status, stdout, stderr = run_cli(['url'], resolver: FakeResolver.new(results: {}))

    assert_equal 1, exit_status
    assert_empty stdout
    assert_includes stderr, 'Usage: dratools url [options] [ACCESSION ...]'
    assert_includes stderr, '--type TYPE'
    assert_includes stderr, 'Examples:'
    refute_includes stderr, 'ACCESSION is required'
  end

  def test_new_subcommands_print_help_to_stderr_when_accession_is_missing
    exit_status, stdout, stderr = run_cli(['size'], resolver: FakeResolver.new(results: {}))

    assert_equal 1, exit_status
    assert_empty stdout
    assert_includes stderr, 'Usage: dratools size [options] [ACCESSION ...]'
    assert_includes stderr, '--json'
    assert_includes stderr, 'Examples:'
  end

  def test_type_option_is_accepted
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001')] })

    exit_status, stdout, stderr = run_cli(
      ['url', '--type', 'fastq', 'DRR000001'],
      resolver: resolver
    )

    assert_equal 0, exit_status
    assert_equal [%w[DRR000001 fastq]], resolver.calls
    assert_equal ['https://example.test/DRR000001.sra'], stdout.lines(chomp: true)
    assert_empty stderr
  end

  def test_invalid_file_type_reports_expected_values
    exit_status, _stdout, stderr = run_cli(
      ['url', '--type', 'fasta', 'DRR000001'],
      resolver: FakeResolver.new(results: {})
    )

    assert_equal 1, exit_status
    assert_includes stderr, "dratools url: invalid --type 'fasta' (expected: sra, fastq, all)"
  end

  def test_unknown_command_is_reported
    exit_status, _stdout, stderr = run_cli(['frobnicate'], resolver: FakeResolver.new(results: {}))

    assert_equal 1, exit_status
    expected = 'dratools: unknown command \'frobnicate\' ' \
               '(expected: url, get, probe, tree, meta, runs, size)'
    assert_includes stderr, expected
  end

  def test_top_level_help_lists_commands_and_examples
    exit_status, stdout, stderr = run_cli(['--help'], resolver: FakeResolver.new(results: {}))

    assert_equal 0, exit_status
    assert_includes stdout, 'Commands:'
    assert_includes stdout, 'Examples:'
    assert_includes stdout, 'dratools url DRR000001'
    assert_empty stderr
  end

  def test_singular_alias_dispatches_to_runs_command
    resolver = FakeResolver.new(
      results: { 'PRJNA1' => [download_for('DRR000001'), download_for('DRR000002')] }
    )

    exit_status, stdout, stderr = run_cli(%w[run PRJNA1], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal %w[DRR000001 DRR000002], stdout.lines(chomp: true)
    assert_empty stderr
  end

  def test_plural_alias_dispatches_to_url_command
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001')] })

    exit_status, stdout, = run_cli(%w[urls DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal ['https://example.test/DRR000001.sra'], stdout.lines(chomp: true)
  end

  def test_runs_prints_unique_run_accessions
    resolver = FakeResolver.new(
      results: {
        'PRJNA1' => [
          download_for('DRR000001'),
          download_for('DRR000002'),
          download_for('DRR000001')
        ]
      }
    )

    exit_status, stdout, stderr = run_cli(%w[runs PRJNA1], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal %w[DRR000001 DRR000002], stdout.lines(chomp: true)
    assert_empty stderr
  end

  def test_runs_deduplicates_run_accessions_across_multiple_inputs
    resolver = FakeResolver.new(
      results: {
        'PRJNA1' => [download_for('DRR000001'), download_for('DRR000002')],
        'PRJNA2' => [download_for('DRR000002'), download_for('DRR000003')]
      }
    )

    exit_status, stdout, stderr = run_cli(%w[runs PRJNA1 PRJNA2], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal %w[DRR000001 DRR000002 DRR000003], stdout.lines(chomp: true)
    assert_empty stderr
  end

  def test_runs_uses_direct_run_xrefs_without_resolving_tree
    resolver = FakeResolver.new(
      direct_run_accessions: { 'ERP1' => 101.times.map { |index| "ERR#{index}" } }
    )

    exit_status, stdout, stderr = run_cli(%w[runs ERP1], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal 101, stdout.lines.length
    assert_includes stdout, "ERR100\n"
    assert_equal ['ERP1'], resolver.direct_run_calls
    assert_empty resolver.calls
    assert_empty resolver.fetch_calls
    assert_empty stderr
  end

  def test_probe_prints_ok_status_to_stdout
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001')] })

    exit_status, stdout, stderr = run_cli(%w[probe DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal "OK\thttps://example.test/DRR000001.sra", stdout.lines(chomp: true).first
    assert_empty stderr
  end

  def test_size_prints_per_accession_and_total
    resolver = FakeResolver.new(
      results: {
        'DRR000001' => [download_for('DRR000001', size: 1024)],
        'DRR000002' => [download_for('DRR000002', size: nil)]
      }
    )

    exit_status, stdout, stderr = run_cli(%w[size DRR000001 DRR000002], resolver: resolver)

    assert_equal 0, exit_status
    lines = stdout.lines(chomp: true)
    assert_equal '#accession	files	size	unresolved', lines[0]
    assert_equal "DRR000001\t1\t1.0 KiB\t0", lines[1]
    assert_equal "DRR000002\t1\tNA\t1", lines[2]
    assert_equal "total\t2\t1.0 KiB\t1", lines[3]
    assert_empty stderr
  end

  def test_size_per_run_groups_downloads_by_run_accession
    resolver = FakeResolver.new(
      results: {
        'DRX1' => [
          download_for('DRR000001', size: 1024),
          download_for('DRR000001', size: 1024),
          download_for('DRR000002', size: 2048)
        ]
      }
    )

    exit_status, stdout, stderr = run_cli(%w[size --per-run DRX1], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal [
      '#accession	files	size	unresolved',
      "DRR000001\t2\t2.0 KiB\t0",
      "DRR000002\t1\t2.0 KiB\t0"
    ], stdout.lines(chomp: true)
    # --per-run の total はデータ行と混ぜず標準エラーに出す。
    assert_equal "total\t3\t4.0 KiB\t0", stderr.lines(chomp: true).first
  end

  def test_size_bytes_marks_size_na_when_all_unresolved
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001', size: nil)] })

    exit_status, stdout, stderr = run_cli(%w[size --bytes DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal "DRR000001\t1\tNA\t1", stdout.lines(chomp: true)[1]
    assert_empty stderr
  end

  def test_size_json_outputs_results
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001', size: 2048)] })

    exit_status, stdout, = run_cli(%w[size --json DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    parsed = JSON.parse(stdout)
    assert_equal 'DRR000001', parsed.first['accession']
    assert_equal 2048, parsed.first['total_size']
  end

  def test_size_rejects_large_direct_run_expansion
    resolver = FakeResolver.new(direct_run_counts: { 'PRJNA1' => 201 })

    exit_status, stdout, stderr = run_cli(%w[size PRJNA1], resolver: resolver)

    assert_equal 1, exit_status
    assert_empty stdout
    assert_includes stderr, 'PRJNA1 has 201 direct runs'
    assert_includes stderr, 'at most 200 direct runs from one parent accession'
    assert_includes stderr, 'DRATOOLS_SIZE_MAX_DIRECT_RUNS=unlimited'
    assert_equal ['PRJNA1'], resolver.count_calls
    assert_empty resolver.fetch_calls
    assert_empty resolver.calls
  end

  def test_size_direct_run_limit_uses_environment
    resolver = FakeResolver.new(
      direct_run_counts: { 'PRJNA1' => 201 },
      results: { 'PRJNA1' => [download_for('SRR0', size: 1024)] }
    )

    with_env('DRATOOLS_SIZE_MAX_DIRECT_RUNS' => '201') do
      exit_status, stdout, stderr = run_cli(%w[size PRJNA1], resolver: resolver)

      assert_equal 0, exit_status
      assert_includes stdout, "PRJNA1\t1\t1.0 KiB"
      assert_equal ['PRJNA1'], resolver.count_calls
      assert_equal ['PRJNA1'], resolver.fetch_calls
      assert_equal [%w[PRJNA1 sra]], resolver.calls
      assert_empty stderr
    end
  end

  def test_invalid_environment_setting_reports_error
    resolver = FakeResolver.new(records: { 'PRJNA1' => { 'dbXrefs' => [] } })

    with_env('DRATOOLS_SIZE_MAX_DIRECT_RUNS' => 'many') do
      exit_status, stdout, stderr = run_cli(
        %w[size PRJNA1],
        resolver: resolver
      )

      assert_equal 1, exit_status
      assert_empty stdout
      assert_includes stderr, "invalid DRATOOLS_SIZE_MAX_DIRECT_RUNS 'many'"
      assert_empty resolver.fetch_calls
    end
  end

  def test_meta_prints_metadata_summary_and_run_count
    resolver = FakeResolver.new(
      results: { 'DRR000001' => [download_for('DRR000001')] },
      records: {
        'DRR000001' => {
          'identifier' => 'DRR000001',
          'type' => 'sra-run',
          'title' => 'Example run',
          'libraryStrategy' => ['WGS'],
          'organism' => { 'identifier' => '8187', 'name' => 'Lates calcarifer' }
        }
      }
    )

    exit_status, stdout, stderr = run_cli(%w[meta DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_includes stdout, 'accession:         DRR000001'
    assert_includes stdout, 'type:              sra-run'
    assert_includes stdout, 'title:             Example run'
    assert_includes stdout, 'libraryStrategy:   WGS'
    assert_includes stdout, 'organism:          Lates calcarifer'
    assert_includes stdout, 'runs:              1'
    refute_includes stdout, '8187, Lates calcarifer'
    assert_empty stderr
  end

  def test_meta_collapses_control_whitespace_in_summary_values
    resolver = FakeResolver.new(
      records: {
        'PRJNA1' => {
          'identifier' => 'PRJNA1',
          'type' => 'bioproject',
          'description' => "This SuperSeries is composed.\r" \
                           'Overall design: Refer to individual Series'
        }
      }
    )

    exit_status, stdout, stderr = run_cli(%w[meta PRJNA1], resolver: resolver)

    assert_equal 0, exit_status
    assert_includes stdout,
                    'description:       This SuperSeries is composed. Overall design: Refer'
    refute_includes stdout, "\r"
    refute_includes stdout, "\nOverall design:"
    assert_empty stderr
  end

  def test_meta_skips_run_count_for_large_non_run_records
    resolver = FakeResolver.new(
      records: {
        'PRJNA1' => {
          'identifier' => 'PRJNA1',
          'type' => 'bioproject',
          'title' => 'Large project'
        }
      }
    )

    exit_status, stdout, stderr = run_cli(%w[meta PRJNA1], resolver: resolver)

    assert_equal 0, exit_status
    assert_includes stdout, 'accession:         PRJNA1'
    refute_includes stdout, 'runs:'
    assert_empty resolver.calls
    assert_empty stderr
  end

  def test_meta_uses_accession_when_identifier_is_missing
    resolver = FakeResolver.new(
      results: { 'DRR000001' => [download_for('DRR000001')] },
      records: {
        'DRR000001' => {
          'accession' => 'DRR000001',
          'type' => 'sra-run'
        }
      }
    )

    exit_status, stdout, stderr = run_cli(%w[meta DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_includes stdout, 'accession:         DRR000001'
    assert_empty stderr
  end

  def test_meta_json_outputs_raw_record
    resolver = FakeResolver.new(records: { 'DRR000001' => { 'identifier' => 'DRR000001' } })

    exit_status, stdout, stderr = run_cli(%w[meta --json DRR000001], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal 'DRR000001', JSON.parse(stdout)['identifier']
    assert_empty stderr
  end

  def test_get_no_verify_disables_checksum_verification
    downloader = FakeDownloader.new
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001')] })

    exit_status, _stdout, stderr = run_cli(
      ['get', '--no-verify', 'DRR000001'],
      resolver: resolver,
      downloader: downloader
    )

    assert_equal 0, exit_status
    assert_equal false, downloader.save_calls.first.last[:verify]
    assert_includes stderr, "Downloaded\t/tmp/downloaded.sra"
    assert_includes stderr, 'dratools get: 1 downloaded, 0 skipped'
  end

  def test_get_force_and_skip_existing_are_passed_to_downloader
    downloader = FakeDownloader.new
    resolver = FakeResolver.new(results: { 'DRR000001' => [download_for('DRR000001')] })

    exit_status, = run_cli(
      ['get', '--force', '--skip-existing', 'DRR000001'],
      resolver: resolver,
      downloader: downloader
    )

    assert_equal 0, exit_status
    assert_equal true, downloader.save_calls.first.last[:force]
    assert_equal true, downloader.save_calls.first.last[:skip_existing]
  end

  def test_get_continues_after_one_download_candidate_failure
    failed_download = Dratools::DownloadCandidate.new(
      run_accession: 'DRR000001_FASTQ',
      type: 'fastq',
      url: 'https://example.test/fastq/DRR000001/'
    )
    successful_download = download_for('DRR000001')
    downloader = FakeDownloader.new(
      save_failures: {
        'DRR000001_FASTQ' => Dratools::InvalidRecordError.new('download URL points to a directory')
      }
    )
    resolver = FakeResolver.new(results: { 'DRR000001' => [failed_download, successful_download] })

    exit_status, _stdout, stderr = run_cli(
      ['get', '--type', 'all', 'DRR000001'],
      resolver: resolver,
      downloader: downloader
    )

    assert_equal 1, exit_status
    assert_equal [failed_download, successful_download], downloader.save_calls.map(&:first)
    assert_includes stderr, 'dratools get: DRR000001: download URL points to a directory'
    assert_includes stderr, "Downloaded\t/tmp/downloaded.sra"
    assert_includes stderr, 'dratools get: 1 downloaded, 0 skipped, 1 failed'
  end

  def test_tree_prints_resolver_tree_without_requiring_downloads
    resolver = FakeResolver.new(results: { 'PRJNA1' => [download_for('SRR000001')] })

    exit_status, stdout, stderr = run_cli(%w[tree PRJNA1], resolver: resolver)

    assert_equal 0, exit_status
    assert_equal [%w[PRJNA1 sra]], resolver.calls
    assert_includes stdout, 'bioproject PRJNA1'
    assert_includes stdout, 'sra https://example.test/SRR000001.sra'
    assert_empty stderr
  end

  def test_tree_max_direct_runs_uses_environment
    resolver = FakeResolver.new(results: { 'PRJNA1' => [download_for('SRR000001')] })

    with_env('DRATOOLS_TREE_MAX_DIRECT_RUNS' => '12') do
      exit_status, _stdout, stderr = run_cli(%w[tree PRJNA1], resolver: resolver)

      assert_equal 0, exit_status
      assert_equal({ direct_run_fetch_limit: 12 }, resolver.tree_options)
      assert_empty stderr
    end
  end

  private

  def download_for(accession, size: nil)
    Dratools::DownloadCandidate.new(
      run_accession: accession,
      type: 'sra',
      url: "https://example.test/#{accession}.sra",
      ftp_url: "ftp://example.test/#{accession}.sra",
      size: size
    )
  end
end
