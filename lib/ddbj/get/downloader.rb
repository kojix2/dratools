# frozen_string_literal: true

require "fileutils"

require_relative "command_runner"

module Ddbj
  module Get
    class Downloader
      def initialize(runner: CommandRunner.new)
        @runner = runner
      end

      def probe(download, protocol: "https", timeout: 5)
        @runner.probe(download.preferred_url(protocol), timeout: timeout)
      end

      def download(download, outdir: ".", protocol: "https")
        FileUtils.mkdir_p(outdir)
        url = download.preferred_url(protocol)
        path = File.join(outdir, download.filename(protocol))
        @runner.download(url, path)
        path
      end
    end
  end
end
