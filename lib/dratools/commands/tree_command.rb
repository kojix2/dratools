# frozen_string_literal: true

require_relative 'base_command'
require_relative '../config'
require_relative '../tree_renderer'

module Dratools
  module Commands
    # accession から run へ辿る探索ツリーを表示する。
    class TreeCommand < BaseCommand
      private

      def command_name
        'tree'
      end

      def usage_examples
        [
          "#{Dratools::NAME} tree PRJNA341783",
          "#{Dratools::NAME} tree --type fastq PRJNA341783"
        ]
      end

      def process(accession)
        direct_run_fetch_limit = Config.tree_max_direct_runs
        tree = @resolver.resolve_tree(
          accession,
          file_type: @options[:file_type],
          direct_run_fetch_limit: direct_run_fetch_limit
        )
        @stdout.puts TreeRenderer.new(
          file_type: @options[:file_type],
          summary_threshold: summary_threshold(direct_run_fetch_limit)
        ).render(tree)
      end

      def summary_threshold(direct_run_fetch_limit)
        [
          TreeRenderer::DEFAULT_SUMMARY_THRESHOLD,
          direct_run_fetch_limit
        ].compact.min
      end
    end
  end
end
