# frozen_string_literal: true

require_relative 'test_helper'

class TreeRendererTest < Minitest::Test
  def test_renders_traversal_tree_with_download_leaves
    root = Dratools::TraversalNode.new(
      type: 'bioproject',
      accession: 'PRJNA341783',
      object_type: 'UmbrellaBioProject',
      children: [
        Dratools::TraversalNode.new(
          relation: Dratools::TraversalNode::CHILD_BIOPROJECT_RELATION,
          type: 'bioproject',
          accession: 'PRJNA341783',
          children: [
            Dratools::TraversalNode.new(
              relation: Dratools::TraversalNode::DB_XREF_RELATION,
              type: 'sra-run',
              accession: 'SRR17168265',
              children: [
                Dratools::TraversalNode.new(
                  relation: Dratools::TraversalNode::DOWNLOAD_RELATION,
                  type: 'sra',
                  url: 'https://example.test/SRR17168265.sra',
                  download: download_for('SRR17168265')
                )
              ]
            )
          ]
        )
      ]
    )

    assert_equal <<~TREE.chomp, Dratools::TreeRenderer.new.render(root)
      bioproject PRJNA341783 UmbrellaBioProject
      └─ childBioProject PRJNA341783
         └─ sra-run SRR17168265
            └─ sra https://example.test/SRR17168265.sra
    TREE
  end

  def test_summarizes_many_run_records_without_requested_downloads
    root = Dratools::TraversalNode.new(
      type: 'bioproject',
      accession: 'PRJNA341783',
      children: 6.times.map do |index|
        Dratools::TraversalNode.new(
          relation: Dratools::TraversalNode::DB_XREF_RELATION,
          type: 'sra-run',
          accession: "SRR#{index}",
          record: { 'type' => 'sra-run', 'identifier' => "SRR#{index}" }
        )
      end
    )

    assert_equal <<~TREE.chomp, Dratools::TreeRenderer.new(file_type: 'fastq').render(root)
      bioproject PRJNA341783
      └─ sra-run 6 records
         └─ no fastq downloads
    TREE
  end

  def test_summarizes_large_unexpanded_run_groups
    root = Dratools::TraversalNode.new(
      type: 'bioproject',
      accession: 'PRJNA341783',
      children: 6.times.map do |index|
        Dratools::TraversalNode.new(
          relation: Dratools::TraversalNode::DB_XREF_RELATION,
          type: 'sra-run',
          accession: "SRR#{index}"
        )
      end
    )

    assert_equal <<~TREE.chomp, Dratools::TreeRenderer.new.render(root)
      bioproject PRJNA341783
      └─ sra-run 6 records
         └─ sra downloads not expanded
    TREE
  end

  def test_summarizes_unexpanded_run_groups_with_lower_threshold
    root = Dratools::TraversalNode.new(
      type: 'bioproject',
      accession: 'PRJNA341783',
      children: 4.times.map do |index|
        Dratools::TraversalNode.new(
          relation: Dratools::TraversalNode::DB_XREF_RELATION,
          type: 'sra-run',
          accession: "SRR#{index}"
        )
      end
    )

    assert_equal <<~TREE.chomp, Dratools::TreeRenderer.new(summary_threshold: 3).render(root)
      bioproject PRJNA341783
      └─ sra-run 4 records
         └─ sra downloads not expanded
    TREE
  end

  private

  def download_for(accession)
    Dratools::DownloadCandidate.new(
      run_accession: accession,
      type: 'sra',
      url: "https://example.test/#{accession}.sra"
    )
  end
end
