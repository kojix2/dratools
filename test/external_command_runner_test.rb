# frozen_string_literal: true

require_relative 'test_helper'

class ExternalCommandRunnerTest < Minitest::Test
  class FakeRunner < Dratools::ExternalCommandRunner
    attr_reader :commands

    def initialize(tool: 'curl')
      super(preferred: tool)
      @tool = tool
      @commands = []
    end

    def available_command
      @tool
    end

    private

    def run_quietly(command)
      @commands << command
      true
    end

    def run_streaming(command)
      @commands << command
      true
    end
  end

  def test_probe_uses_curl_range_and_timeout
    runner = FakeRunner.new

    assert runner.probe_url('https://example.test/run.sra', timeout: 3)
    command = runner.commands.first
    assert_includes command, '--range'
    assert_includes command, '0-0'
    assert_includes command, '--max-time'
    assert_includes command, '3'
  end

  def test_download_streams_curl_with_stall_detection
    runner = FakeRunner.new

    assert runner.download_url('https://example.test/run.sra', '/tmp/run.sra')
    command = runner.commands.first
    assert_includes command, '--connect-timeout'
    assert_includes command, '30'
    assert_includes command, '--speed-limit'
    assert_includes command, '1024'
    assert_includes command, '--speed-time'
    assert_includes command, '60'
    assert_includes command, '--retry'
    assert_includes command, '3'
  end

  def test_download_streams_curl_with_environment_tuning
    runner = FakeRunner.new

    with_env(
      'DRATOOLS_DOWNLOAD_CONNECT_TIMEOUT' => '1',
      'DRATOOLS_DOWNLOAD_STALL_SPEED' => '2',
      'DRATOOLS_DOWNLOAD_STALL_TIMEOUT' => '3',
      'DRATOOLS_DOWNLOAD_RETRY_COUNT' => '0'
    ) do
      assert runner.download_url('https://example.test/run.sra', '/tmp/run.sra')
    end

    command = runner.commands.first
    assert_includes command, '--connect-timeout'
    assert_includes command, '1'
    assert_includes command, '--speed-limit'
    assert_includes command, '2'
    assert_includes command, '--speed-time'
    assert_includes command, '3'
    assert_includes command, '--retry'
    assert_includes command, '0'
  end

  def test_probe_uses_wget_spider_and_timeout
    runner = FakeRunner.new(tool: 'wget')

    assert runner.probe_url('https://example.test/run.sra', timeout: 3)
    command = runner.commands.first
    assert_includes command, '--spider'
    assert_includes command, '--timeout=3'
    assert_includes command, '--tries=1'
  end

  def test_download_streams_wget_with_stall_detection
    runner = FakeRunner.new(tool: 'wget')

    assert runner.download_url('https://example.test/run.sra', '/tmp/run.sra')
    command = runner.commands.first
    assert_includes command, '--continue'
    assert_includes command, '--connect-timeout=30'
    assert_includes command, '--read-timeout=60'
    assert_includes command, '--tries=3'
    assert_includes command, '--waitretry=5'
  end

  def test_download_streams_wget_with_environment_tuning
    runner = FakeRunner.new(tool: 'wget')

    with_env(
      'DRATOOLS_DOWNLOAD_CONNECT_TIMEOUT' => '1',
      'DRATOOLS_DOWNLOAD_STALL_TIMEOUT' => '3',
      'DRATOOLS_DOWNLOAD_RETRY_COUNT' => '0',
      'DRATOOLS_DOWNLOAD_RETRY_WAIT' => '4'
    ) do
      assert runner.download_url('https://example.test/run.sra', '/tmp/run.sra')
    end

    command = runner.commands.first
    assert_includes command, '--connect-timeout=1'
    assert_includes command, '--read-timeout=3'
    assert_includes command, '--tries=0'
    assert_includes command, '--waitretry=4'
  end
end
