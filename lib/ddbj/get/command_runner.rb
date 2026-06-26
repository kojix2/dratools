# frozen_string_literal: true

require "open3"
require "rbconfig"
require "shellwords"

require_relative "errors"

module Ddbj
  module Get
    class CommandRunner
      def initialize(preferred: nil)
        @preferred = preferred
      end

      def available
        candidates = [@preferred, "curl", "wget"].compact
        candidates.find { |cmd| executable?(cmd) }
      end

      def probe(url, timeout: 5)
        tool = available || raise(CommandError, "curl または wget が見つかりません")
        # 巨大ファイルを落とさないよう、短時間・最小範囲の確認に留める。
        command =
          if File.basename(tool) == "curl"
            [tool, "--location", "--fail", "--silent", "--show-error",
             "--range", "0-0", "--max-time", timeout.to_s, "--output", null_device, url]
          else
            [tool, "--spider", "--timeout=#{timeout}", "--tries=1", url]
          end
        run(command)
      end

      def download(url, output_path)
        tool = available || raise(CommandError, "curl または wget が見つかりません")
        command =
          if File.basename(tool) == "curl"
            [tool, "--location", "--fail", "--continue-at", "-", "--output", output_path, url]
          else
            [tool, "--continue", "--output-document", output_path, url]
          end
        run(command)
      end

      private

      def run(command)
        stdout, stderr, status = Open3.capture3(*command)
        return true if status.success?

        raise CommandError, "#{command.shelljoin}\n#{stdout}#{stderr}"
      end

      def executable?(cmd)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          path = File.join(dir, cmd)
          File.file?(path) && File.executable?(path)
        end
      end

      def null_device
        RbConfig::CONFIG["host_os"].match?(/mswin|mingw/) ? "NUL" : "/dev/null"
      end
    end
  end
end
