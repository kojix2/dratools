# frozen_string_literal: true

require_relative 'base_command'

module Dratools
  module Commands
    # accession を run accession のフラットな一覧に展開する。
    class RunsCommand < BaseCommand
      private

      def command_name
        'runs'
      end

      def usage_examples
        [
          "#{Dratools::NAME} runs PRJNA341783",
          "#{Dratools::NAME} runs PRJNA341783 | #{Dratools::NAME} get -O ~/Downloads"
        ]
      end

      def process(accession)
        direct_runs = direct_run_accessions_for(accession)
        if direct_runs.any?
          run_accessions.concat(direct_runs)
          return
        end

        tree = @resolver.resolve_tree(accession, file_type: @options[:file_type])
        run_accessions.concat(tree.run_accessions)
      end

      def finalize
        run_accessions.uniq.each { |run_accession| @stdout.puts run_accession }
      end

      def run_accessions
        @run_accessions ||= []
      end

      def direct_run_accessions_for(accession)
        @resolver.direct_run_accessions_for(accession)
      end
    end
  end
end
