# frozen_string_literal: true

require 'open3'
require 'shellwords'
require 'English'

require_relative 'config'
require_relative 'errors'

module Dratools
  # curl か wget を使って URL の確認とダウンロードを行うラッパー。
  #
  # probe は短時間・無出力で済ませ、download は外部コマンドの進捗を端末へ流す。
  # 巨大ファイルを扱うため、download には総時間制限ではなく失速検知を使う。
  class ExternalCommandRunner
    CURL_COMMAND = 'curl'
    WGET_COMMAND = 'wget'
    SUPPORTED_COMMANDS = [CURL_COMMAND, WGET_COMMAND].freeze
    COMMAND_NOT_FOUND_MESSAGE = 'curl または wget が見つかりません'
    DEFAULT_PROBE_TIMEOUT_SECONDS = 5
    PROBE_BYTE_RANGE = '0-0'
    SINGLE_ATTEMPT_COUNT = 1

    # curl probe:
    # --location はリダイレクトを辿る。DDBJ の URL は別ホストへ転送されることがある。
    # --fail は HTTP エラーを成功扱いにしない。
    # --silent と --show-error は進捗を消しつつ、失敗理由だけ表示する。
    # --range 0-0 は巨大ファイル本体を落とさず、先頭 1 byte だけ取得して到達性を見る。
    CURL_PROBE_OPTIONS = ['--location', '--fail', '--silent', '--show-error', '--range'].freeze
    CURL_TIMEOUT_OPTION = '--max-time'
    CURL_CONNECT_TIMEOUT_OPTION = '--connect-timeout'
    CURL_SPEED_LIMIT_OPTION = '--speed-limit'
    CURL_SPEED_TIME_OPTION = '--speed-time'
    CURL_RETRY_OPTION = '--retry'
    CURL_OUTPUT_OPTION = '--output'
    # curl download:
    # --continue-at - は既存の部分ファイルがあれば続きから再開する。
    # 総時間の上限は付けない。数十 GB のファイルでは正常でも長時間かかるため。
    # 代わりに接続タイムアウト、低速状態の検知、リトライを download_url で追加する。
    CURL_DOWNLOAD_OPTIONS = ['--location', '--fail', '--continue-at', '-'].freeze

    # wget probe:
    # --spider はファイルを保存せず、URL が取得可能かだけ確認する。
    # --timeout と --tries=1 は短時間の疎通確認で待ち続けないために付ける。
    WGET_PROBE_OPTIONS = ['--spider'].freeze
    WGET_TIMEOUT_OPTION = '--timeout'
    WGET_CONNECT_TIMEOUT_OPTION = '--connect-timeout'
    WGET_READ_TIMEOUT_OPTION = '--read-timeout'
    WGET_TRIES_OPTION = '--tries'
    WGET_WAITRETRY_OPTION = '--waitretry'
    WGET_CONTINUE_OPTION = '--continue'
    WGET_OUTPUT_OPTION = '--output-document'

    def initialize(preferred: nil)
      @preferred = preferred
    end

    def available_command
      candidates = [@preferred, *SUPPORTED_COMMANDS].compact
      candidates.find { |command_name| executable_command?(command_name) }
    end

    def probe_url(url, timeout: DEFAULT_PROBE_TIMEOUT_SECONDS)
      tool = available_command || raise(CommandError, COMMAND_NOT_FOUND_MESSAGE)
      # 巨大ファイルを落とさないよう、短時間・最小範囲の確認に留める。
      command =
        if File.basename(tool) == CURL_COMMAND
          [tool, *CURL_PROBE_OPTIONS, PROBE_BYTE_RANGE, CURL_TIMEOUT_OPTION, timeout.to_s,
           CURL_OUTPUT_OPTION, null_device, url]
        else
          [tool, *WGET_PROBE_OPTIONS, "#{WGET_TIMEOUT_OPTION}=#{timeout}",
           "#{WGET_TRIES_OPTION}=#{SINGLE_ATTEMPT_COUNT}", url]
        end
      run_quietly(command)
    end

    def download_url(url, output_path)
      tool = available_command || raise(CommandError, COMMAND_NOT_FOUND_MESSAGE)
      command =
        if File.basename(tool) == CURL_COMMAND
          # curl の低速検知は「指定秒数のあいだ指定速度を下回ったら失敗」。
          # ネットワークが完全に切れず低速で固まるケースを、総時間制限なしで検出する。
          [tool, *CURL_DOWNLOAD_OPTIONS,
           CURL_CONNECT_TIMEOUT_OPTION, Config.download_connect_timeout_seconds.to_s,
           CURL_SPEED_LIMIT_OPTION, Config.download_stall_speed_bytes_per_second.to_s,
           CURL_SPEED_TIME_OPTION, Config.download_stall_timeout_seconds.to_s,
           CURL_RETRY_OPTION, Config.download_retry_count.to_s,
           CURL_OUTPUT_OPTION, output_path, url]
        else
          # wget では --read-timeout を失速検知に近い意味で使う。
          # --continue は部分ファイルの続きから再開し、--output-document は保存先を固定する。
          [tool, WGET_CONTINUE_OPTION,
           "#{WGET_CONNECT_TIMEOUT_OPTION}=#{Config.download_connect_timeout_seconds}",
           "#{WGET_READ_TIMEOUT_OPTION}=#{Config.download_stall_timeout_seconds}",
           "#{WGET_TRIES_OPTION}=#{Config.download_retry_count}",
           "#{WGET_WAITRETRY_OPTION}=#{Config.download_retry_wait_seconds}",
           WGET_OUTPUT_OPTION, output_path, url]
        end
      run_streaming(command)
    end

    private

    def run_quietly(command)
      out, err, status = Open3.capture3(*command)
      return true if status.success?

      raise CommandError, "#{command.shelljoin}\n#{out}#{err}"
    end

    def run_streaming(command)
      # 配列形式で渡すことでシェルを介さず、curl/wget の stderr 進捗はそのまま見せる。
      return true if system(*command)

      status = $CHILD_STATUS
      detail = status ? "exit status: #{status.exitstatus}" : 'command failed'
      raise CommandError, "#{command.shelljoin}\n#{detail}"
    end

    def executable_command?(command_name)
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? do |directory|
        command_path = File.join(directory, command_name)
        File.file?(command_path) && File.executable?(command_path)
      end
    end

    def null_device
      File::NULL
    end
  end
end
