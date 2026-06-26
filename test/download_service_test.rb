# frozen_string_literal: true

require_relative 'test_helper'

class DownloadServiceTest < Minitest::Test
  class FakeHttpDownloadService < Dratools::DownloadService
    def initialize(responses, runner: WritingRunner.new)
      super(runner: runner)
      @responses = responses
    end

    private

    def get_http_response(request_uri, timeout:)
      @responses.fetch([:get, request_uri.to_s, timeout])
    end

    def head_http_response(request_uri, timeout:)
      @responses.fetch([:head, request_uri.to_s, timeout])
    end
  end

  class WritingRunner
    attr_reader :download_calls

    def initialize
      @download_calls = []
    end

    def probe_url(*)
      true
    end

    def download_url(_url, output_path)
      @download_calls << output_path
      File.write(output_path, 'hello')
    end
  end

  class ExistingFileObserverRunner
    attr_reader :file_existed_at_download

    def download_url(_url, output_path)
      @file_existed_at_download = File.exist?(output_path)
      File.write(output_path, 'fresh')
    end
  end

  def test_save_download_verifies_md5_when_available
    download = download_for(md5: '5d41402abc4b2a76b9719d911017c592')

    Dir.mktmpdir do |directory|
      result = Dratools::DownloadService.new(runner: WritingRunner.new).save_download(
        download,
        outdir: directory
      )

      assert_equal File.join(directory, 'DRR000001.sra'), result.path
      assert_equal false, result.skipped?
    end
  end

  def test_save_download_raises_on_md5_mismatch
    download = download_for(md5: '00000000000000000000000000000000')

    Dir.mktmpdir do |directory|
      assert_raises(Dratools::ChecksumError) do
        Dratools::DownloadService.new(runner: WritingRunner.new).save_download(
          download,
          outdir: directory
        )
      end
    end
  end

  def test_save_download_can_skip_md5_verification
    download = download_for(md5: '00000000000000000000000000000000')

    Dir.mktmpdir do |directory|
      result = Dratools::DownloadService.new(runner: WritingRunner.new).save_download(
        download,
        outdir: directory,
        verify: false
      )

      assert_equal File.join(directory, 'DRR000001.sra'), result.path
    end
  end

  def test_save_download_skips_existing_file_when_md5_matches
    download = download_for(md5: '5d41402abc4b2a76b9719d911017c592')
    runner = WritingRunner.new

    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'DRR000001.sra')
      File.write(output_path, 'hello')

      result = Dratools::DownloadService.new(runner: runner).save_download(
        download,
        outdir: directory
      )

      assert_equal output_path, result.path
      assert result.skipped?
      assert_empty runner.download_calls
    end
  end

  def test_save_download_force_downloads_even_when_md5_matches
    download = download_for(md5: '5d41402abc4b2a76b9719d911017c592')
    runner = WritingRunner.new

    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'DRR000001.sra')
      File.write(output_path, 'hello')

      result = Dratools::DownloadService.new(runner: runner).save_download(
        download,
        outdir: directory,
        force: true
      )

      assert_equal output_path, result.path
      assert_equal false, result.skipped?
      assert_equal [output_path], runner.download_calls
    end
  end

  def test_save_download_skip_existing_skips_without_md5
    download = download_for(md5: nil)
    runner = WritingRunner.new

    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'DRR000001.sra')
      File.write(output_path, 'partial')

      result = Dratools::DownloadService.new(runner: runner).save_download(
        download,
        outdir: directory,
        skip_existing: true
      )

      assert_equal output_path, result.path
      assert result.skipped?
      assert_empty runner.download_calls
    end
  end

  def test_save_download_skips_complete_existing_file_without_md5
    download = download_for(md5: nil)
    runner = WritingRunner.new
    success = response_with_content_length(7)

    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'DRR000001.sra')
      File.write(output_path, 'partial')
      service = FakeHttpDownloadService.new(
        { [:head, 'https://example.test/DRR000001.sra', 10] => success },
        runner: runner
      )

      result = service.save_download(download, outdir: directory)

      assert_equal output_path, result.path
      assert result.skipped?
      assert_empty runner.download_calls
    end
  end

  def test_save_download_resumes_partial_existing_file_without_md5
    download = download_for(md5: nil)
    runner = WritingRunner.new
    success = response_with_content_length(100)

    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'DRR000001.sra')
      File.write(output_path, 'partial')
      service = FakeHttpDownloadService.new(
        { [:head, 'https://example.test/DRR000001.sra', 10] => success },
        runner: runner
      )

      result = service.save_download(download, outdir: directory)

      assert_equal output_path, result.path
      assert_equal false, result.skipped?
      assert_equal [output_path], runner.download_calls
    end
  end

  def test_save_download_rejects_existing_file_larger_than_remote_without_md5
    download = download_for(md5: nil)
    runner = WritingRunner.new
    success = response_with_content_length(3)

    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'DRR000001.sra')
      File.write(output_path, 'too large')
      service = FakeHttpDownloadService.new(
        { [:head, 'https://example.test/DRR000001.sra', 10] => success },
        runner: runner
      )

      error = assert_raises(Dratools::InvalidRecordError) do
        service.save_download(download, outdir: directory)
      end

      assert_includes error.message, 'existing file is larger than remote file'
      assert_empty runner.download_calls
    end
  end

  def test_save_download_force_removes_existing_file_before_download
    download = download_for(md5: nil)
    runner = ExistingFileObserverRunner.new

    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'DRR000001.sra')
      File.write(output_path, 'old')

      result = Dratools::DownloadService.new(runner: runner).save_download(
        download,
        outdir: directory,
        force: true
      )

      assert_equal output_path, result.path
      assert_equal false, runner.file_existed_at_download
      assert_equal 'fresh', File.read(output_path)
    end
  end

  def test_save_download_rejects_directory_url
    download = Dratools::DownloadCandidate.new(
      run_accession: 'DRR000001',
      type: 'fastq',
      url: 'https://example.test/fastq/DRA000/DRR000001/'
    )
    runner = WritingRunner.new

    Dir.mktmpdir do |directory|
      error = assert_raises(Dratools::InvalidRecordError) do
        Dratools::DownloadService.new(runner: runner).save_download(
          download,
          outdir: directory
        )
      end

      assert_includes error.message, 'download URL points to a directory'
      assert_empty runner.download_calls
    end
  end

  def test_content_lengths_reads_head_content_length
    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success['content-length'] = '1234'
    download = download_for(md5: nil)
    responses = {
      [:head, 'https://example.test/DRR000001.sra', 3] => success
    }
    service = FakeHttpDownloadService.new(responses)

    assert_equal [1234], service.content_lengths(download, timeout: 3)
  end

  def test_content_lengths_follows_head_redirect
    redirect = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redirect['location'] = 'https://archive.example.test/DRR000001.sra'
    success = Net::HTTPOK.new('1.1', '200', 'OK')
    success['content-length'] = '5678'
    download = download_for(md5: nil)
    responses = {
      [:head, 'https://example.test/DRR000001.sra', 3] => redirect,
      [:head, 'https://archive.example.test/DRR000001.sra', 3] => success
    }
    service = FakeHttpDownloadService.new(responses)

    assert_equal [5678], service.content_lengths(download, timeout: 3)
  end

  def test_content_lengths_expands_fastq_directory
    index = Net::HTTPOK.new('1.1', '200', 'OK')
    index.instance_variable_set(:@read, true)
    index.body = <<~HTML
      <a href="DRR000001_1.fastq.bz2">DRR000001_1.fastq.bz2</a>
      <a href="DRR000001_2.fastq.bz2">DRR000001_2.fastq.bz2</a>
      <a href="notes.txt">notes.txt</a>
    HTML
    first = Net::HTTPOK.new('1.1', '200', 'OK')
    first['content-length'] = '100'
    second = Net::HTTPOK.new('1.1', '200', 'OK')
    second['content-length'] = '200'
    download = Dratools::DownloadCandidate.new(
      run_accession: 'DRR000001',
      type: 'fastq',
      url: 'https://example.test/fastq/DRR000001/'
    )
    responses = {
      [:get, 'https://example.test/fastq/DRR000001/', 3] => index,
      [:head, 'https://example.test/fastq/DRR000001/DRR000001_1.fastq.bz2', 3] => first,
      [:head, 'https://example.test/fastq/DRR000001/DRR000001_2.fastq.bz2', 3] => second
    }
    service = FakeHttpDownloadService.new(responses)

    assert_equal [100, 200], service.content_lengths(download, timeout: 3)
  end

  def test_content_lengths_keeps_successful_fastq_sizes_when_one_head_fails
    index = Net::HTTPOK.new('1.1', '200', 'OK')
    index.instance_variable_set(:@read, true)
    index.body = <<~HTML
      <a href="DRR000001_1.fastq.bz2">DRR000001_1.fastq.bz2</a>
      <a href="DRR000001_2.fastq.bz2">DRR000001_2.fastq.bz2</a>
    HTML
    first = Net::HTTPOK.new('1.1', '200', 'OK')
    first['content-length'] = '100'
    second = Net::HTTPInternalServerError.new('1.1', '500', 'Internal Server Error')
    download = Dratools::DownloadCandidate.new(
      run_accession: 'DRR000001',
      type: 'fastq',
      url: 'https://example.test/fastq/DRR000001/'
    )
    responses = {
      [:get, 'https://example.test/fastq/DRR000001/', 3] => index,
      [:head, 'https://example.test/fastq/DRR000001/DRR000001_1.fastq.bz2', 3] => first,
      [:head, 'https://example.test/fastq/DRR000001/DRR000001_2.fastq.bz2', 3] => second
    }
    service = FakeHttpDownloadService.new(responses)

    assert_equal [100, nil], service.content_lengths(download, timeout: 3)
  end

  def test_content_lengths_returns_nil_for_ftp_url
    download = Dratools::DownloadCandidate.new(
      run_accession: 'DRR000001',
      type: 'sra',
      url: nil,
      ftp_url: 'ftp://example.test/DRR000001.sra'
    )

    assert_equal [nil], Dratools::DownloadService.new.content_lengths(download, protocol: 'ftp')
  end

  private

  def response_with_content_length(length)
    Net::HTTPOK.new('1.1', '200', 'OK').tap do |response|
      response['content-length'] = length.to_s
    end
  end

  def download_for(md5:)
    Dratools::DownloadCandidate.new(
      run_accession: 'DRR000001',
      type: 'sra',
      url: 'https://example.test/DRR000001.sra',
      md5: md5
    )
  end
end
