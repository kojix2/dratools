# frozen_string_literal: true

require_relative 'test_helper'

class TraversalNodeTest < Minitest::Test
  def test_collects_run_accessions_without_download_leaves
    root = Dratools::TraversalNode.new(
      type: 'bioproject',
      accession: 'PRJNA1',
      children: [
        Dratools::TraversalNode.new(type: 'sra-run', accession: 'DRR000001'),
        Dratools::TraversalNode.new(
          type: 'sra-run',
          accession: 'DRR000002',
          children: [
            Dratools::TraversalNode.new(
              relation: Dratools::TraversalNode::DOWNLOAD_RELATION,
              type: 'sra',
              accession: 'DRR000002',
              download: Dratools::DownloadCandidate.new(type: 'sra', run_accession: 'DRR000002')
            )
          ]
        )
      ]
    )

    assert_equal %w[DRR000001 DRR000002], root.run_accessions
  end
end
