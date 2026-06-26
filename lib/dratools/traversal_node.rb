# frozen_string_literal: true

module Dratools
  # DDBJ record traversal and download leaves for tree rendering.
  class TraversalNode
    ROOT_RELATION = :root
    DB_XREF_RELATION = :db_xref
    CHILD_BIOPROJECT_RELATION = :child_bioproject
    DOWNLOAD_RELATION = :download

    attr_reader :relation, :type, :accession, :object_type, :record, :url, :error, :children,
                :download

    def initialize( # rubocop:disable Metrics/ParameterLists
      relation: ROOT_RELATION,
      type: nil,
      accession: nil,
      object_type: nil,
      record: nil,
      url: nil,
      error: nil,
      children: [],
      download: nil
    )
      @relation = relation
      @type = type
      @accession = accession
      @object_type = object_type
      @record = record
      @url = url
      @error = error
      @children = children
      @download = download
    end

    def run?
      type == DdbjRecordFields::SRA_RUN_RESOURCE_TYPE
    end

    def download?
      relation == DOWNLOAD_RELATION
    end

    def errored?
      !error.to_s.empty?
    end

    def run_records
      records = run? && record ? [record] : []
      records + children.flat_map(&:run_records)
    end

    def run_accessions
      accessions = run? && accession ? [accession] : []
      accessions + children.reject(&:download?).flat_map(&:run_accessions)
    end

    def downloads
      own_downloads = download ? [download] : []
      own_downloads + children.flat_map(&:downloads)
    end

    def errors
      own_errors = errored? ? [error] : []
      own_errors + children.flat_map(&:errors)
    end
  end
end
