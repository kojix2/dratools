# frozen_string_literal: true

require_relative 'test_helper'

class DownloadCandidateBuilderTest < Minitest::Test
  def test_builds_distribution_candidates_and_skips_non_file_entries
    downloads = Dratools::DownloadCandidateBuilder.new.build_from_run_record(
      'identifier' => 'DRR000001',
      'distribution' => [
        {
          'encodingFormat' => 'JSON',
          'contentUrl' => 'https://example.test/DRR000001.json'
        },
        {
          'encodingFormat' => 'SRA',
          'contentUrl' => 'https://example.test/DRR000001.sra',
          'contentSize' => 456,
          'md5' => 'def456'
        }
      ]
    )

    assert_equal 1, downloads.length
    assert_equal 'DRR000001', downloads.first.run_accession
    assert_equal 'sra', downloads.first.type
    assert_equal 'https://example.test/DRR000001.sra', downloads.first.url
    assert_nil downloads.first.ftp_url
    assert_equal 456, downloads.first.size
    assert_equal 'def456', downloads.first.md5
  end

  def test_deduplicates_distribution_candidates
    downloads = Dratools::DownloadCandidateBuilder.new.build_from_run_record(
      'identifier' => 'DRR000001',
      'distribution' => [
        {
          'encodingFormat' => 'SRA',
          'contentUrl' => 'https://example.test/DRR000001.sra'
        },
        {
          'encodingFormat' => 'SRA',
          'contentUrl' => 'https://example.test/DRR000001.sra'
        }
      ]
    )

    assert_equal 1, downloads.length
  end
end
