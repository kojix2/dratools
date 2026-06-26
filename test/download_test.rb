# frozen_string_literal: true

require_relative "test_helper"

class DownloadTest < Minitest::Test
  def test_prefers_https_url
    download = Ddbj::Get::Download.new(
      type: "sra",
      url: "https://ddbj.nig.ac.jp/path/run.sra",
      ftp_url: "ftp://ftp.ddbj.nig.ac.jp/path/run.sra"
    )

    assert_equal "https://ddbj.nig.ac.jp/path/run.sra", download.preferred_url("https")
    assert_equal "run.sra", download.filename
  end

  def test_prefers_ftp_url
    download = Ddbj::Get::Download.new(
      type: "sra",
      url: "https://ddbj.nig.ac.jp/path/run.sra",
      ftp_url: "ftp://ftp.ddbj.nig.ac.jp/path/run.sra"
    )

    assert_equal "ftp://ftp.ddbj.nig.ac.jp/path/run.sra", download.preferred_url("ftp")
  end
end
