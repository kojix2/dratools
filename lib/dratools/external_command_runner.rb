# frozen_string_literal: true

require 'open3'
require 'shellwords'
require 'English'

require_relative 'config'
require_relative 'errors'

module Dratools
  # curl, wget, aria2c のいずれかを使って URL の確認とダウンロードを行うラッパー。
  #
  # probe は短時間・無出力で済ませ、download は外部コマンドの進捗を端末へ流す。
  # 巨大ファイルを扱うため、download には総時間制限ではなく失速検知を使う。
  class ExternalCommandRunner
    CURL_COMMAND = 'curl'
    WGET_COMMAND = 'wget'
    ARIA2_COMMAND = 'aria2c'
    AUTO_COMMANDS = [CURL_COMMAND, WGET_COMMAND].freeze
    SUPPORTED_COMMANDS = [*AUTO_COMMANDS, ARIA2_COMMAND].freeze

    COMMAND_NOT_FOUND_MESSAGE = 'curl または wget が見つかりません'
    PREFERRED_COMMAND_NOT_FOUND_MESSAGE = '指定されたダウンロードコマンドが見つかりません'
    UNSUPPORTED_COMMAND_MESSAGE = '未対応のダウンロードコマンドです'
    DEFAULT_PROBE_TIMEOUT_SECONDS = 5
    PROBE_BYTE_RANGE = '0-0'
    SINGLE_ATTEMPT_COUNT = 1

    # リダイレクト、HTTP エラー、静かな probe、範囲取得。
    CURL_PROBE_OPTIONS = ['--location', '--fail', '--silent', '--show-error', '--range'].freeze
    # probe 全体のタイムアウト。
    CURL_TIMEOUT_OPTION = '--max-time'
    CURL_CONNECT_TIMEOUT_OPTION = '--connect-timeout'
    # 失速判定に使う最低転送速度。
    CURL_SPEED_LIMIT_OPTION = '--speed-limit'
    # 最低速度を下回ってよい秒数。
    CURL_SPEED_TIME_OPTION = '--speed-time'
    CURL_RETRY_OPTION = '--retry'
    CURL_OUTPUT_OPTION = '--output'
    # 部分ファイルがあれば続きから再開。
    CURL_DOWNLOAD_OPTIONS = ['--location', '--fail', '--continue-at', '-'].freeze

    # probe でファイルを保存しない。
    WGET_PROBE_OPTIONS = ['--spider'].freeze
    # probe 全体のタイムアウト。
    WGET_TIMEOUT_OPTION = '--timeout'
    WGET_CONNECT_TIMEOUT_OPTION = '--connect-timeout'
    # wget で失速検知に近い意味で使う。
    WGET_READ_TIMEOUT_OPTION = '--read-timeout'
    # probe では 1 回だけにする。
    WGET_TRIES_OPTION = '--tries'
    WGET_WAITRETRY_OPTION = '--waitretry'
    # 部分ファイルがあれば続きから再開。
    WGET_CONTINUE_OPTION = '--continue'
    WGET_OUTPUT_OPTION = '--output-document'

    # probe で保存せず、通常出力も抑える。
    ARIA2_PROBE_OPTIONS = ['--dry-run=true', '--quiet=true'].freeze
    ARIA2_CONNECT_TIMEOUT_OPTION = '--connect-timeout'
    # aria2c で失速検知に近い意味で使う。
    ARIA2_TIMEOUT_OPTION = '--timeout'
    # curl の --speed-limit に相当する最低転送速度。
    ARIA2_LOWEST_SPEED_LIMIT_OPTION = '--lowest-speed-limit'
    ARIA2_MAX_TRIES_OPTION = '--max-tries'
    ARIA2_RETRY_WAIT_OPTION = '--retry-wait'
    # 部分ファイルがあれば続きから再開。
    ARIA2_CONTINUE_OPTION = '--continue=true'
    # aria2c は保存先をディレクトリとファイル名に分ける。
    ARIA2_DIR_OPTION = '--dir'
    ARIA2_OUT_OPTION = '--out'
    # 既定では並列取得しない。
    ARIA2_SINGLE_CONNECTION_OPTIONS = ['--split=1', '--max-connection-per-server=1'].freeze

    def initialize(preferred: Config.download_command)
      @preferred = preferred
    end

    def available_command
      candidates = @preferred ? [@preferred] : AUTO_COMMANDS
      candidates.find { |command_name| executable_command?(command_name) }
    end

    def probe_url(url, timeout: DEFAULT_PROBE_TIMEOUT_SECONDS)
      tool = available_command || raise(CommandError, command_not_found_message)
      # 巨大ファイルを落とさないよう、短時間・最小範囲の確認に留める。
      command =
        case File.basename(tool)
        when CURL_COMMAND
          # 例: curl --location --fail --silent --show-error --range 0-0
          #          --max-time 5 --output /dev/null URL
          [tool, *CURL_PROBE_OPTIONS, PROBE_BYTE_RANGE, CURL_TIMEOUT_OPTION, timeout.to_s,
           CURL_OUTPUT_OPTION, null_device, url]
        when WGET_COMMAND
          # 例: wget --spider --timeout=5 --tries=1 URL
          [tool, *WGET_PROBE_OPTIONS, "#{WGET_TIMEOUT_OPTION}=#{timeout}",
           "#{WGET_TRIES_OPTION}=#{SINGLE_ATTEMPT_COUNT}", url]
        when ARIA2_COMMAND
          # 例: aria2c --dry-run=true --quiet=true --connect-timeout=5 --timeout=5 --max-tries=1 URL
          [tool, *ARIA2_PROBE_OPTIONS,
           "#{ARIA2_CONNECT_TIMEOUT_OPTION}=#{timeout}",
           "#{ARIA2_TIMEOUT_OPTION}=#{timeout}",
           "#{ARIA2_MAX_TRIES_OPTION}=#{SINGLE_ATTEMPT_COUNT}", url]
        else
          unsupported_command!(tool)
        end
      run_quietly(command)
    end

    def download_url(url, output_path)
      tool = available_command || raise(CommandError, command_not_found_message)
      command =
        case File.basename(tool)
        when CURL_COMMAND
          # curl の低速検知は「指定秒数のあいだ指定速度を下回ったら失敗」。
          # ネットワークが完全に切れず低速で固まるケースを、総時間制限なしで検出する。
          # 例: curl --location --fail --continue-at - --connect-timeout 30
          #          --speed-limit 1024 --speed-time 60 --retry 3 --output OUT URL
          [tool, *CURL_DOWNLOAD_OPTIONS,
           CURL_CONNECT_TIMEOUT_OPTION, Config.download_connect_timeout_seconds.to_s,
           CURL_SPEED_LIMIT_OPTION, Config.download_stall_speed_bytes_per_second.to_s,
           CURL_SPEED_TIME_OPTION, Config.download_stall_timeout_seconds.to_s,
           CURL_RETRY_OPTION, Config.download_retry_count.to_s,
           CURL_OUTPUT_OPTION, output_path, url]
        when WGET_COMMAND
          # wget では --read-timeout を失速検知に近い意味で使う。
          # --continue は部分ファイルの続きから再開し、--output-document は保存先を固定する。
          # 例: wget --continue --connect-timeout=30 --read-timeout=60
          #          --tries=4 --waitretry=5 --output-document OUT URL
          [tool, WGET_CONTINUE_OPTION,
           "#{WGET_CONNECT_TIMEOUT_OPTION}=#{Config.download_connect_timeout_seconds}",
           "#{WGET_READ_TIMEOUT_OPTION}=#{Config.download_stall_timeout_seconds}",
           "#{WGET_TRIES_OPTION}=#{download_attempt_count}",
           "#{WGET_WAITRETRY_OPTION}=#{Config.download_retry_wait_seconds}",
           WGET_OUTPUT_OPTION, output_path, url]
        when ARIA2_COMMAND
          # aria2c は保存先をディレクトリとファイル名に分けて指定する。
          # --continue=true は部分ファイルがあれば続きから再開する。
          # 例: aria2c --continue=true --split=1 --max-connection-per-server=1
          #          --connect-timeout=30 --timeout=60 --lowest-speed-limit=1024
          #          --max-tries=4 --retry-wait=5 --dir DIR --out FILE URL
          [tool, ARIA2_CONTINUE_OPTION, *ARIA2_SINGLE_CONNECTION_OPTIONS,
           "#{ARIA2_CONNECT_TIMEOUT_OPTION}=#{Config.download_connect_timeout_seconds}",
           "#{ARIA2_TIMEOUT_OPTION}=#{Config.download_stall_timeout_seconds}",
           "#{ARIA2_LOWEST_SPEED_LIMIT_OPTION}=#{Config.download_stall_speed_bytes_per_second}",
           "#{ARIA2_MAX_TRIES_OPTION}=#{download_attempt_count}",
           "#{ARIA2_RETRY_WAIT_OPTION}=#{Config.download_retry_wait_seconds}",
           "#{ARIA2_DIR_OPTION}=#{File.dirname(output_path)}",
           "#{ARIA2_OUT_OPTION}=#{File.basename(output_path)}", url]
        else
          unsupported_command!(tool)
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
      # 配列形式で渡すことでシェルを介さず、外部コマンドの stderr 進捗はそのまま見せる。
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

    def command_not_found_message
      return "#{PREFERRED_COMMAND_NOT_FOUND_MESSAGE}: #{@preferred}" if @preferred

      COMMAND_NOT_FOUND_MESSAGE
    end

    def download_attempt_count
      Config.download_retry_count + 1
    end

    def unsupported_command!(tool)
      raise CommandError, "#{UNSUPPORTED_COMMAND_MESSAGE}: #{tool}"
    end

    def null_device
      File::NULL
    end
  end
end
