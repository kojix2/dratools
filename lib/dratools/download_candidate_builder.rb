# frozen_string_literal: true

require_relative 'ddbj_record_fields'
require_relative 'download_candidate'

module Dratools
  # DDBJ run レコードの downloadUrl/distribution から DownloadCandidate を作る。
  class DownloadCandidateBuilder
    def build_from_run_record(run_record)
      run_accession = run_accession_from(run_record)
      downloads = download_items_from(run_record).filter_map do |download_item|
        build_from_download_item(run_accession, download_item)
      end
      downloads.uniq { |download| download_key(download) }
    end

    private

    def run_accession_from(run_record)
      run_record[DdbjRecordFields::ACCESSION_KEY] ||
        run_record[DdbjRecordFields::IDENTIFIER_KEY] ||
        run_record[DdbjRecordFields::ID_KEY] ||
        run_record[DdbjRecordFields::PRIMARY_ID_KEY]
    end

    def download_items_from(ddbj_record)
      ddbj_record.fetch(DdbjRecordFields::DOWNLOAD_URL_KEY, []) +
        ddbj_record.fetch(DdbjRecordFields::DISTRIBUTION_KEY, [])
    end

    def build_from_download_item(run_accession, download_item)
      return unless download_item.is_a?(Hash)

      if download_item[DdbjRecordFields::CONTENT_URL_KEY]
        build_from_distribution_item(run_accession, download_item)
      else
        build_from_download_url_item(run_accession, download_item)
      end
    end

    def build_from_distribution_item(run_accession, download_item)
      file_type = file_type_from_distribution(download_item)
      return unless file_type

      DownloadCandidate.new(
        run_accession: run_accession,
        type: file_type,
        url: download_item[DdbjRecordFields::CONTENT_URL_KEY],
        ftp_url: nil,
        size: download_item[DdbjRecordFields::CONTENT_SIZE_KEY],
        md5: download_item[DdbjRecordFields::MD5_KEY] || download_item[DdbjRecordFields::MD5_SUM_KEY]
      )
    end

    def build_from_download_url_item(run_accession, download_item)
      file_type = file_type_from_download_url(download_item)
      return unless file_type

      DownloadCandidate.new(
        run_accession: run_accession,
        type: file_type,
        url: download_item[DdbjRecordFields::URL_KEY],
        ftp_url: download_item[DdbjRecordFields::FTP_URL_KEY],
        size: download_item[DdbjRecordFields::SIZE_KEY] || download_item[DdbjRecordFields::FILE_SIZE_KEY],
        md5: download_item[DdbjRecordFields::MD5_KEY] || download_item[DdbjRecordFields::MD5_SUM_KEY]
      )
    end

    def file_type_from_distribution(download_item)
      file_type_from(download_item[DdbjRecordFields::ENCODING_FORMAT_KEY])
    end

    def file_type_from_download_url(download_item)
      file_type_from(download_item[DdbjRecordFields::TYPE_KEY])
    end

    def file_type_from(value)
      case value.to_s.downcase
      when DdbjRecordFields::FILE_TYPE_SRA
        DdbjRecordFields::FILE_TYPE_SRA
      when DdbjRecordFields::FILE_TYPE_FASTQ
        DdbjRecordFields::FILE_TYPE_FASTQ
      end
    end

    def download_key(download)
      [download.type, download.url, download.ftp_url]
    end
  end
end
