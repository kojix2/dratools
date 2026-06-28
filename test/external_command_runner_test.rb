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
    assert_includes command, '--tries=4'
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
    assert_includes command, '--tries=1'
    assert_includes command, '--waitretry=4'
  end

  def test_probe_uses_aria2c_dry_run_and_timeout
    runner = FakeRunner.new(tool: 'aria2c')

    assert runner.probe_url('https://example.test/run.sra', timeout: 3)
    command = runner.commands.first
    assert_includes command, '--dry-run=true'
    assert_includes command, '--quiet=true'
    assert_includes command, '--connect-timeout=3'
    assert_includes command, '--timeout=3'
    assert_includes command, '--max-tries=1'
  end

  def test_download_streams_aria2c_with_single_connection_and_output_parts
    runner = FakeRunner.new(tool: 'aria2c')

    assert runner.download_url('https://example.test/run.sra', '/tmp/downloads/run.sra')
    command = runner.commands.first
    assert_includes command, '--continue=true'
    assert_includes command, '--split=1'
    assert_includes command, '--max-connection-per-server=1'
    assert_includes command, '--connect-timeout=30'
    assert_includes command, '--timeout=60'
    assert_includes command, '--lowest-speed-limit=1024'
    assert_includes command, '--max-tries=4'
    assert_includes command, '--retry-wait=5'
    assert_includes command, '--dir=/tmp/downloads'
    assert_includes command, '--out=run.sra'
  end

  def test_download_streams_aria2c_with_environment_tuning
    runner = FakeRunner.new(tool: 'aria2c')

    with_env(
      'DRATOOLS_DOWNLOAD_CONNECT_TIMEOUT' => '1',
      'DRATOOLS_DOWNLOAD_STALL_SPEED' => '2',
      'DRATOOLS_DOWNLOAD_STALL_TIMEOUT' => '3',
      'DRATOOLS_DOWNLOAD_RETRY_COUNT' => '0',
      'DRATOOLS_DOWNLOAD_RETRY_WAIT' => '4'
    ) do
      assert runner.download_url('https://example.test/run.sra', '/tmp/run.sra')
    end

    command = runner.commands.first
    assert_includes command, '--connect-timeout=1'
    assert_includes command, '--lowest-speed-limit=2'
    assert_includes command, '--timeout=3'
    assert_includes command, '--max-tries=1'
    assert_includes command, '--retry-wait=4'
  end

  def test_environment_can_select_download_command
    Dir.mktmpdir do |directory|
      curl_path = File.join(directory, 'curl')
      wget_path = File.join(directory, 'wget')
      aria2c_path = File.join(directory, 'aria2c')
      File.write(curl_path, '')
      File.write(wget_path, '')
      File.write(aria2c_path, '')
      File.chmod(0o755, curl_path)
      File.chmod(0o755, wget_path)
      File.chmod(0o755, aria2c_path)

      with_env(
        'PATH' => directory,
        'DRATOOLS_DOWNLOAD_COMMAND' => 'aria2c'
      ) do
        assert_equal 'aria2c', Dratools::ExternalCommandRunner.new.available_command
      end
    end
  end

  def test_auto_selection_does_not_use_aria2c
    Dir.mktmpdir do |directory|
      aria2c_path = File.join(directory, 'aria2c')
      File.write(aria2c_path, '')
      File.chmod(0o755, aria2c_path)

      with_env(
        'PATH' => directory,
        'DRATOOLS_DOWNLOAD_COMMAND' => nil
      ) do
        assert_nil Dratools::ExternalCommandRunner.new.available_command
      end
    end
  end

  def test_environment_download_command_does_not_fall_back
    Dir.mktmpdir do |directory|
      curl_path = File.join(directory, 'curl')
      File.write(curl_path, '')
      File.chmod(0o755, curl_path)

      with_env(
        'PATH' => directory,
        'DRATOOLS_DOWNLOAD_COMMAND' => 'wget'
      ) do
        error = assert_raises(Dratools::CommandError) do
          Dratools::ExternalCommandRunner.new.probe_url('https://example.test/run.sra')
        end

        assert_includes error.message, '指定されたダウンロードコマンドが見つかりません: wget'
      end
    end
  end

  def test_probe_rejects_unsupported_command
    runner = FakeRunner.new(tool: 'axel')

    error = assert_raises(Dratools::CommandError) do
      runner.probe_url('https://example.test/run.sra')
    end

    assert_includes error.message, '未対応のダウンロードコマンドです: axel'
  end

  def test_download_rejects_unsupported_command
    runner = FakeRunner.new(tool: 'axel')

    error = assert_raises(Dratools::CommandError) do
      runner.download_url('https://example.test/run.sra', '/tmp/run.sra')
    end

    assert_includes error.message, '未対応のダウンロードコマンドです: axel'
  end
end
