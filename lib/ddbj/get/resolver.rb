# frozen_string_literal: true

require "set"

require_relative "client"
require_relative "download"
require_relative "errors"

module Ddbj
  module Get
    class Resolver
      RUN_PREFIXES = /\A[DES]RR\d+\z/
      EXPERIMENT_PREFIXES = /\A[DES]RX\d+\z/
      SAMPLE_PREFIXES = /\A[DES]RS\d+\z/
      STUDY_PREFIXES = /\A[DES]RP\d+\z/
      SUBMISSION_PREFIXES = /\A[DES]RA\d+\z/
      BIOPROJECT_PREFIXES = /\APRJ(?:DB|NA|EB)\d+\z/
      BIOSAMPLE_PREFIXES = /\ASAM(?:D|N|EA|EG)?\d+\z/

      TYPE_BY_ACCESSION = [
        [RUN_PREFIXES, "sra-run"],
        [EXPERIMENT_PREFIXES, "sra-experiment"],
        [SAMPLE_PREFIXES, "sra-sample"],
        [STUDY_PREFIXES, "sra-study"],
        [SUBMISSION_PREFIXES, "sra-submission"],
        [BIOPROJECT_PREFIXES, "bioproject"],
        [BIOSAMPLE_PREFIXES, "biosample"]
      ].freeze

      def initialize(client: Client.new)
        @client = client
      end

      def resolve(accession, file_type: "sra")
        accession = accession.to_s.upcase
        record = fetch_by_accession(accession)
        runs = collect_runs(record)
        runs = [record] if run_record?(record)
        downloads = runs.flat_map { |run| downloads_from_run(run) }
        downloads.select! { |download| file_type == "all" || download.type == file_type }
        raise NotFoundError, "download URL not found: #{accession} (type=#{file_type})" if downloads.empty?

        downloads
      end

      def fetch_by_accession(accession)
        type = type_for(accession)
        @client.resource(type, accession)
      end

      def type_for(accession)
        pair = TYPE_BY_ACCESSION.find { |pattern, _type| pattern.match?(accession) }
        raise UnsupportedAccessionError, "unsupported accession: #{accession}" unless pair

        pair.last
      end

      private

      def collect_runs(record, seen = Set.new)
        return [record] if run_record?(record)

        # BioProject などの上位レコードから sra-run への参照をたどる。
        xrefs = record.fetch("dbXrefs", [])
        xrefs.each_with_object([]) do |xref, runs|
          next unless xref["type"] == "sra-run"

          url = xref["url"].to_s
          key = url.empty? ? xref["id"].to_s : url
          next if key.empty? || seen.include?(key)

          seen.add(key)
          runs.concat(collect_runs(fetch_xref(xref), seen))
        end
      end

      def fetch_xref(xref)
        # DDBJ Search の画面URLと resource API URL の両方を許容する。
        if xref["url"].to_s.match?(%r{/resource/([^/]+)/([^/.]+)})
          @client.resource(Regexp.last_match(1), Regexp.last_match(2))
        elsif xref["url"].to_s.match?(%r{/search/entry/([^/]+)/([^/?#.]+)})
          @client.resource(Regexp.last_match(1), Regexp.last_match(2))
        elsif xref["id"]
          @client.resource(xref["type"], xref["id"])
        else
          raise NotFoundError, "sra-run xref has no URL or id"
        end
      end

      def run_record?(record)
        record["type"] == "sra-run" || record["downloadUrl"].is_a?(Array)
      end

      def downloads_from_run(record)
        # downloadUrl は DDBJ Search の実ファイル情報。ここでは型を変えず薄く包む。
        run = record["accession"] || record["id"] || record["primaryId"]
        record.fetch("downloadUrl", []).filter_map do |item|
          next unless item.is_a?(Hash)

          Download.new(
            run_accession: run,
            type: item["type"],
            url: item["url"],
            ftp_url: item["ftpUrl"],
            size: item["size"] || item["fileSize"],
            md5: item["md5"] || item["md5sum"]
          )
        end
      end
    end
  end
end
