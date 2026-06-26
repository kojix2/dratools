# frozen_string_literal: true

require_relative 'test_helper'

class DownloadCandidateTest < Minitest::Test
  def test_prefers_https_url
    download = Dratools::DownloadCandidate.new(
      type: 'sra',
      url: 'https://ddbj.nig.ac.jp/path/run.sra',
      ftp_url: 'ftp://ftp.ddbj.nig.ac.jp/path/run.sra'
    )

    assert_equal 'https://ddbj.nig.ac.jp/path/run.sra', download.url_for_protocol('https')
    assert_equal 'run.sra', download.filename_for_protocol
  end

  def test_prefers_ftp_url
    download = Dratools::DownloadCandidate.new(
      type: 'sra',
      url: 'https://ddbj.nig.ac.jp/path/run.sra',
      ftp_url: 'ftp://ftp.ddbj.nig.ac.jp/path/run.sra'
    )

    assert_equal 'ftp://ftp.ddbj.nig.ac.jp/path/run.sra', download.url_for_protocol('ftp')
  end

  def test_rejects_unknown_protocol
    download = Dratools::DownloadCandidate.new(
      type: 'sra',
      url: 'https://ddbj.nig.ac.jp/path/run.sra'
    )

    assert_raises(Dratools::InvalidProtocolError) do
      download.url_for_protocol('rsync')
    end
  end

  def test_detects_directory_urls
    download = Dratools::DownloadCandidate.new(
      type: 'fastq',
      url: 'https://ddbj.nig.ac.jp/public/ddbj_database/dra/fastq/DRA000/DRR000001/'
    )

    assert download.directory_url_for_protocol?
  end
end
