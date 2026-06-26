# frozen_string_literal: true

require_relative "../test_helper"

class DdbjSearchIntegrationTest < Minitest::Test
  def setup
    skip "DDBJ_GET_INTEGRATION=1 の時だけ実行します" unless ENV["DDBJ_GET_INTEGRATION"] == "1"
  end

  def test_resolves_and_probes_public_dra_sra
    resolver = Ddbj::Get::Resolver.new
    downloads = resolver.resolve("DRR000001", file_type: "sra")

    refute_empty downloads
    assert_match(/DRR000001\.sra\z/, downloads.first.preferred_url("https"))

    downloader = Ddbj::Get::Downloader.new
    assert downloader.probe(downloads.first, timeout: 5)
  end
end
