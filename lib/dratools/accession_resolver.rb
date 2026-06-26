# frozen_string_literal: true

require_relative 'accession_resource_type_classifier'
require_relative 'ddbj_record_fields'
require_relative 'ddbj_resource_client'
require_relative 'download_candidate_builder'
require_relative 'errors'
require_relative 'run_record_collector'
require_relative 'traversal_node'

module Dratools
  # accession を受け取り、DDBJ 上の実ファイル候補へ解決する調停役。
  class AccessionResolver
    FILE_TYPE_SRA = DdbjRecordFields::FILE_TYPE_SRA
    FILE_TYPE_FASTQ = DdbjRecordFields::FILE_TYPE_FASTQ
    FILE_TYPE_ALL = DdbjRecordFields::FILE_TYPE_ALL

    def initialize(
      client: DdbjResourceClient.new,
      resource_type_classifier: AccessionResourceTypeClassifier.new,
      run_record_collector: nil,
      download_candidate_builder: DownloadCandidateBuilder.new
    )
      @client = client
      @resource_type_classifier = resource_type_classifier
      @run_record_collector = run_record_collector || RunRecordCollector.new(client: client)
      @download_candidate_builder = download_candidate_builder
    end

    def resolve_downloads(accession, file_type: FILE_TYPE_SRA)
      accession = accession.to_s.upcase
      ddbj_record = fetch_record_for(accession)
      resolve_downloads_from_record(accession, ddbj_record, file_type: file_type)
    end

    def resolve_downloads_from_record(accession, ddbj_record, file_type: FILE_TYPE_SRA)
      tree = resolve_tree_from_record(accession, ddbj_record, file_type: file_type, tolerant: false)
      downloads = tree.downloads
      if downloads.empty?
        raise NotFoundError, "download URL not found: #{accession.to_s.upcase} (type=#{file_type})"
      end

      downloads
    end

    def resolve_tree(accession, file_type: FILE_TYPE_SRA, tolerant: true,
                     direct_run_fetch_limit: nil)
      accession = accession.to_s.upcase
      ddbj_record = fetch_record_for(accession)
      resolve_tree_from_record(
        accession,
        ddbj_record,
        file_type: file_type,
        tolerant: tolerant,
        direct_run_fetch_limit: direct_run_fetch_limit
      )
    end

    def resolve_tree_from_record(_accession, ddbj_record, file_type: FILE_TYPE_SRA, tolerant: true,
                                 direct_run_fetch_limit: nil)
      tree = @run_record_collector.explore(
        ddbj_record,
        tolerant: tolerant,
        direct_run_fetch_limit: direct_run_fetch_limit
      )
      attach_downloads(tree, file_type: file_type)
      tree
    end

    def fetch_record_for(accession)
      resource_type = resource_type_for(accession)
      @client.fetch_resource_record(resource_type, accession)
    end

    def resource_type_for(accession)
      @resource_type_classifier.resource_type_for(accession)
    end

    private

    def attach_downloads(node, file_type:)
      if node.run? && node.record
        downloads = @download_candidate_builder.build_from_run_record(node.record)
        downloads.select! { |download| file_type == FILE_TYPE_ALL || download.type == file_type }
        node.children.concat(downloads.map { |download| download_node(download) })
      end

      node.children.each do |child|
        attach_downloads(child, file_type: file_type) unless child.download?
      end
      node
    end

    def download_node(download)
      TraversalNode.new(
        relation: TraversalNode::DOWNLOAD_RELATION,
        type: download.type,
        accession: download.run_accession,
        url: download.url,
        download: download
      )
    end
  end
end
