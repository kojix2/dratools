# frozen_string_literal: true

require_relative '../test_helper'

class DdbjSearchIntegrationTest < Minitest::Test
  def setup
    skip 'DRATOOLS_INTEGRATION=1 の時だけ実行します' unless ENV['DRATOOLS_INTEGRATION'] == '1'
  end

  def test_resolves_and_probes_public_dra_sra
    resolver = Dratools::AccessionResolver.new
    downloads = resolver.resolve_downloads('DRR000001', file_type: 'sra')

    refute_empty downloads
    assert_match(/DRR000001\.sra\z/, downloads.first.url_for_protocol('https'))

    downloader = Dratools::DownloadService.new
    assert downloader.probe_download(downloads.first, timeout: 5)
  end
end
