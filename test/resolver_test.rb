# frozen_string_literal: true

require_relative "test_helper"

class ResolverTest < Minitest::Test
  class FakeClient
    def initialize(records)
      @records = records
    end

    def resource(type, accession)
      @records.fetch([type, accession])
    end
  end

  def test_resolves_run_sra_download
    client = FakeClient.new(
      ["sra-run", "DRR000001"] => {
        "type" => "sra-run",
        "accession" => "DRR000001",
        "downloadUrl" => [
          {
            "type" => "sra",
            "url" => "https://ddbj.nig.ac.jp/public/ddbj_database/dra/sra/x/DRR000001.sra",
            "ftpUrl" => "ftp://ftp.ddbj.nig.ac.jp/ddbj_database/dra/sra/x/DRR000001.sra",
            "size" => 123
          },
          {
            "type" => "fastq",
            "url" => "https://ddbj.nig.ac.jp/public/ddbj_database/dra/fastq/x/DRR000001.fastq.bz2"
          }
        ]
      }
    )
    resolver = Ddbj::Get::Resolver.new(client: client)

    downloads = resolver.resolve("DRR000001")

    assert_equal 1, downloads.length
    assert_equal "DRR000001", downloads.first.run_accession
    assert_equal "sra", downloads.first.type
    assert_equal 123, downloads.first.size
  end

  def test_resolves_bioproject_to_runs
    client = FakeClient.new(
      ["bioproject", "PRJDB1"] => {
        "type" => "bioproject",
        "accession" => "PRJDB1",
        "dbXrefs" => [
          {
            "type" => "sra-run",
            "url" => "https://ddbj.nig.ac.jp/resource/sra-run/DRR000001"
          }
        ]
      },
      ["sra-run", "DRR000001"] => {
        "type" => "sra-run",
        "accession" => "DRR000001",
        "downloadUrl" => [
          {
            "type" => "sra",
            "url" => "https://example.test/DRR000001.sra"
          }
        ]
      }
    )
    resolver = Ddbj::Get::Resolver.new(client: client)

    downloads = resolver.resolve("PRJDB1")

    assert_equal ["https://example.test/DRR000001.sra"], downloads.map(&:url)
  end

  def test_filters_fastq_downloads
    client = FakeClient.new(
      ["sra-run", "DRR000001"] => {
        "downloadUrl" => [
          {"type" => "sra", "url" => "https://example.test/DRR000001.sra"},
          {"type" => "fastq", "url" => "https://example.test/DRR000001.fastq.bz2"}
        ]
      }
    )
    resolver = Ddbj::Get::Resolver.new(client: client)

    downloads = resolver.resolve("DRR000001", file_type: "fastq")

    assert_equal ["fastq"], downloads.map(&:type)
  end

  def test_rejects_unknown_accession
    resolver = Ddbj::Get::Resolver.new(client: FakeClient.new({}))

    assert_raises(Ddbj::Get::UnsupportedAccessionError) do
      resolver.resolve("XYZ123")
    end
  end
end
